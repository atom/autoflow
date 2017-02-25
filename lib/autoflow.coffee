_ = require 'underscore-plus'

CharacterPattern = ///
  [
    \w                                     # English
    \u0410-\u042F\u0401\u0430-\u044F\u0451 # Cyrillic
  ]
///

module.exports =
  activate: ->
    atom.commands.add 'atom-text-editor',
      'autoflow:reflow-selection': (event) =>
        @reflowSelection(event.currentTarget.getModel())

  reflowSelection: (editor) ->
    range = editor.getSelectedBufferRange()
    range = editor.getCurrentParagraphBufferRange() if range.isEmpty()
    return unless range?

    reflowOptions =
        wrapColumn: @getPreferredLineLength(editor)
        tabLength: @getTabLength(editor)
    reflowedText = @reflow(editor.getTextInRange(range), reflowOptions)
    editor.getBuffer().setTextInRange(range, reflowedText)

  reflow: (text, {wrapColumn, tabLength}) ->
    paragraphs = []
    # Convert all \r\n and \r to \n. The text buffer will normalize them later
    text = text.replace(/\r\n?/g, '\n')

    leadingVerticalSpace = text.match(/^\s*\n/)
    if leadingVerticalSpace
      text = text.substr(leadingVerticalSpace.length)
    else
      leadingVerticalSpace = ''

    trailingVerticalSpace = text.match(/\n\s*$/)
    if trailingVerticalSpace
      text = text.substr(0, text.length - trailingVerticalSpace.length)
    else
      trailingVerticalSpace = ''

    paragraphBlocks = text.split(/\n\s*\n/g)
    if tabLength
      tabLengthInSpaces = Array(tabLength + 1).join(' ')
    else
      tabLengthInSpaces = ''

    for block in paragraphBlocks

      # TODO: this could be more language specific. Use the actual comment char.
      linePrefix = block.match(/^\s*[\/#*-]*\s*/g)[0]
      linePrefixTabExpanded = linePrefix
      if tabLengthInSpaces
        linePrefixTabExpanded = linePrefix.replace(/\t/g, tabLengthInSpaces)
      blockLines = block.split('\n')

      if linePrefix
        escapedLinePrefix = _.escapeRegExp(linePrefix)
        blockLines = blockLines.map (blockLine) ->
          blockLine.replace(///^#{escapedLinePrefix}///, '')

      blockLines = blockLines.map (blockLine) ->
        blockLine.replace(/^\s+/, '')

      if blockLines.length > 1
        blockLastLine = blockLines.pop()
        blockLines = blockLines.map (blockLine) ->
          blockLine.replace(/\s+$/, '')
        blockLines.push(blockLastLine)

      lines = []
      currentLine = []
      currentLineLength = linePrefixTabExpanded.length

      for segment in @segmentText(blockLines.join(' '))
        if @wrapSegment(segment, currentLineLength, wrapColumn)
          lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          currentLineLength = linePrefixTabExpanded.length
        currentLine.push(segment)
        currentLineLength += segment.length
      lines.push(linePrefix + currentLine.join(''))

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))

    leadingVerticalSpace + paragraphs.join('\n\n') + trailingVerticalSpace

  getTabLength: (editor) ->
    atom.config.get('editor.tabLength', scope: editor.getRootScopeDescriptor()) ? 2

  getPreferredLineLength: (editor) ->
    atom.config.get('editor.preferredLineLength', scope: editor.getRootScopeDescriptor())

  wrapSegment: (segment, currentLineLength, wrapColumn) ->
    CharacterPattern.test(segment) and
      (currentLineLength + segment.length > wrapColumn) and
      (currentLineLength > 0 or segment.length < wrapColumn)

  segmentText: (text) ->
    segments = []
    re = /[\s]+|[^\s]+/g
    segments.push(match[0]) while match = re.exec(text)
    segments
