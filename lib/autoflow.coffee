_ = require 'underscore-plus'

CharacterPattern = ///
  [
    \w                                     # English
    \u0410-\u042F\u0401\u0430-\u044F\u0451 # Cyrillic
  ]
///

module.exports =
  config:
    algorithm:
      title: 'Reflow Algorithm'
      description: '''
      This determines how text is reflowed. The two options are to either just
      [put as many words as possible on each
      line](https://en.wikipedia.org/wiki/Line_wrap_and_word_wrap#Minimum_number_of_lines),
      or to [try to avoid getting very short lines after
      reflowing](https://en.wikipedia.org/wiki/Line_wrap_and_word_wrap#Minimum_raggedness).
      '''
      type: 'string'
      default: 'greedy'
      enum: [
        {value: 'greedy', description: 'Put as many words as possible on each line'}
        {value: 'minimumRaggedness', description: 'Avoid short lines after reflow'}
      ]

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
        algorithm: @getAlgorithm(editor)
    reflowedText = @reflow(editor.getTextInRange(range), reflowOptions)
    editor.getBuffer().setTextInRange(range, reflowedText)

  reflow: (text, {wrapColumn, tabLength, algorithm}) ->
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

    @reflowNonPrefixedLines = @greedyReflow
    if algorithm is "minimumRaggedness"
      @reflowNonPrefixedLines = @minimumRaggednessReflow

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

      lines = @reflowNonPrefixedLines(blockLines.join(' '),
                                      wrapColumn - linePrefixTabExpanded.length)
      lines = lines.map (line) ->
        linePrefix + line

      paragraphs.push(lines.join('\n').replace(/\s+\n/g, '\n'))

    leadingVerticalSpace + paragraphs.join('\n\n') + trailingVerticalSpace

  # Greedy reflow; just put as many words as possible on each line
  greedyReflow: (text, wrapColumn) ->
    lines = []
    currentLine = []
    currentLineLength = 0

    for segment in @segmentText(text)
      # A segment is basically a word or whitespace
      if @wrapSegment(segment, currentLineLength, wrapColumn)
        lines.push(currentLine.join(''))
        currentLine = []
        currentLineLength = 0
      currentLine.push(segment)
      currentLineLength += segment.length
    lines.push(currentLine.join(''))

    return lines

# Minimum raggedness algorithm ported from http://xxyxyz.org/line-breaking.
  #
  # This is the "Shortest path" one.
  minimumRaggednessReflow: (text, wrapColumn) ->
    VERY_MUCH = 10**6

    words = text.split /[\s]+/
    count = words.length
    if count.length is 0
      return []

    offsets = [0]
    for segment in words
      offsets.push(offsets[offsets.length - 1] + segment.length)

    minima = [0].concat(VERY_MUCH for [1..count])
    breaks = (0 for [0..count])
    for i in [0..(count - 1)]
      j = i + 1
      # "i" is the index of the first word of the current line
      # "j" is the index of the last word of the current line

      while j <= count
        chars_i_to_j = offsets[j] - offsets[i]
        spaces_i_to_j = j - i - 1
        width_i_to_j = chars_i_to_j + spaces_i_to_j
        if width_i_to_j > wrapColumn
          if j is (i + 1)
            # This is a single word that is longer than the allowed line length,
            # just take as it is and pretend it was perfect.
            #
            # "Perfect" in this case means that no extra penalty is incurred by
            # breaking here.
            minima[j] = minima[i]
            breaks[j] = i
            j += 1

          break

        current_line_penalty = (wrapColumn - width_i_to_j) ** 2
        if j is count
          # We're on the last line, we don't care how short this one is.
          #
          # The reason this is the last line is that the last word of the
          # current line (j) is the last word of the text (count).
          current_line_penalty = 0

        cost = minima[i] + current_line_penalty
        if cost < minima[j]
          minima[j] = cost
          breaks[j] = i
        j += 1

    lines = []
    j = count
    while j > 0
      i = breaks[j]
      if (j > i)
        lines.push(words[i..(j - 1)].join(' '))
      j = i

    lines.reverse()
    return lines

  getAlgorithm: (editor) ->
    atom.config.get('autoflow.algorithm')

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
