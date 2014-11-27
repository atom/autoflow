module.exports =
  activate: ->
    atom.commands.add 'atom-text-editor',
      'autoflow:reflow-selection': (event) =>
        @reflowSelection(event.target.getModel())

  reflowSelection: (editor) ->
    range = editor.getSelectedBufferRange()
    range = editor.getCurrentParagraphBufferRange() if range.isEmpty()

    if range?
      editor.getBuffer().setTextInRange(range, @reflow(editor.getTextInRange(range), {wrapColumn: @getPreferredLineLength()}))

  reflow: (text, {wrapColumn}) ->
    paragraphs = []
    paragraphBlocks = text.split(/\n\s*\n/g)

    for block in paragraphBlocks

      # TODO: this could be more language specific. Use the actual comment char.
      linePrefix = block.match(/^\s*[\/#*-]*\s*/g)[0]
      blockLines = block.split('\n')
      blockLines = (blockLine.replace(new RegExp('^' + linePrefix.replace('*', '\\*')), '') for blockLine in blockLines) if linePrefix

      lines = []
      currentLine = []
      currentLineLength = linePrefix.length

      for segment in @segmentText(blockLines.join(' '))
        if @wrapSegment(segment, currentLineLength, wrapColumn)
          lines.push(linePrefix + currentLine.join(''))
          currentLine = []
          currentLineLength = linePrefix.length
        currentLine.push(segment)
        currentLineLength += segment.length
      lines.push(linePrefix + currentLine.join(''))

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))

    paragraphs.join('\n\n')

  getPreferredLineLength: ->
    atom.config.get('editor.preferredLineLength')

  wrapSegment: (segment, currentLineLength, wrapColumn) ->
    /\w/.test(segment) and
      (currentLineLength + segment.length > wrapColumn) and
      (currentLineLength > 0 or segment.length < wrapColumn)

  segmentText: (text) ->
    segments = []
    re = /[\s]+|[^\s]+/g
    segments.push(match[0]) while match = re.exec(text)
    segments
