_ = require 'underscore-plus'
{Point} = require 'atom'

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
    originalText = editor.getTextInRange(range)
    reflowedText = @reflow(originalText, reflowOptions)
    oldCursorPoint = editor.getCursorBufferPosition()
    editor.getBuffer().setTextInRange(range, reflowedText)

    # make sure the cursor is at the correct position after the reflow:
    # find cursor position in string before reflow,
    # and then calculate row and column from string after reflow
    # only do that if the reflow was not in a selection
    if editor.getSelectedBufferRange().isEmpty()
      relCursorPoint = new Point(oldCursorPoint.row - range.start.row,
                                 oldCursorPoint.column - range.start.column)
      relCursorPos = @posFromPoint(originalText, relCursorPoint)
      newRelCursorPoint = @pointFromPos(reflowedText, relCursorPos)
      newCursorPoint = range.start.translate(newRelCursorPoint)
      editor.setCursorBufferPosition(newCursorPoint)

  reflow: (text, {wrapColumn, tabLength}) ->
    paragraphs = []
    # Convert all \r\n and \r to \n. The text buffer will normalize them later
    text = text.replace(/\r\n?/g, '\n')
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

    paragraphs.join('\n\n')

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

  posFromPoint: (text, point) ->
    # Given a Point in buffer coordinates, find the corresponding position in the String text
    splitText = text.split('\n')
    characterNumbers = (line.length + 1 for line in splitText)
    characterNumbers.splice(point.row, characterNumbers.length - point.row)
    pos = _.reduce(characterNumbers, ((memo, num) -> memo + num), 0) + point.column
    pos

  pointFromPos: (text, pos) ->
    # Given a position in the String text, find the corresponding Point in buffer coordinates
    splitText = text.split('\n')
    row = 0
    col = -1
    totalCharacters = 0
    for line in splitText
      do (line) ->
        totalCharacters += line.length + 1
        if totalCharacters <= pos
          row++
        else
          col = pos - totalCharacters + line.length + 1 if col is -1
    point = new Point(row, col)
    point
