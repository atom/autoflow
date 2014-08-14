{WorkspaceView} = require 'atom'

describe "Autoflow package", ->
  [autoflow, editor, editorView] = []

  describe "autoflow:reflow-selection", ->
    beforeEach ->
      activationPromise = null
      atom.workspaceView = new WorkspaceView

      waitsForPromise ->
        atom.workspace.open()

      runs ->
        atom.workspaceView.attachToDom()

        editorView = atom.workspaceView.getActiveView()
        {editor} = editorView

        atom.config.set('editor.preferredLineLength', 30)

        activationPromise = atom.packages.activatePackage('autoflow')

        editorView.trigger 'autoflow:reflow-selection' # Trigger the activation event

      waitsForPromise ->
        activationPromise

    it "rearranges line breaks in the current selection to ensure lines are shorter than config.editor.preferredLineLength", ->
      editor.setText """
        This is the first paragraph and it is longer than the preferred line length so it should be reflowed.

        This is a short paragraph.

        Another long paragraph, it should also be reflowed with the use of this single command.
      """

      editor.selectAll()
      editorView.trigger 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        This is the first paragraph
        and it is longer than the
        preferred line length so it
        should be reflowed.

        This is a short paragraph.

        Another long paragraph, it
        should also be reflowed with
        the use of this single
        command.
      """


    it "reflows the current paragraph if nothing is selected", ->
      editor.setText """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over the lazy
        dog. The preceding sentence contains every letter
        in the entire English alphabet, which has absolutely no relevance
        to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

      editor.setCursorBufferPosition([3, 5])
      editorView.trigger 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over
        the lazy dog. The preceding
        sentence contains every letter
        in the entire English
        alphabet, which has absolutely
        no relevance to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

    it "allows for single words that exceed the preferred wrap column length", ->
      editor.setText("this-is-a-super-long-word-that-shouldn't-break-autoflow and these are some smaller words")

      editor.selectAll()
      editorView.trigger 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        this-is-a-super-long-word-that-shouldn't-break-autoflow
        and these are some smaller
        words
      """

  describe "reflowing text", ->
    beforeEach ->
      atom.workspaceView = new WorkspaceView
      autoflow = require("../lib/autoflow")

    it 'respects current paragraphs', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Phasellus gravida
        nibh id magna ullamcorper
        tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
        rutrum nisl fermentum rhoncus. Duis blandit ligula facilisis fermentum.
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
        rutrum nisl fermentum rhoncus. Duis blandit ligula facilisis fermentum.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects indentation', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

            Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            Phasellus gravida
            nibh id magna ullamcorper
            tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
            rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis fermentum
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
            nibh id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis
            erat dolor. rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis
            fermentum
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects prefixed text (comments!)', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

          #  Lorem ipsum dolor sit amet, consectetur adipiscing elit.
          #  Phasellus gravida
          #  nibh id magna ullamcorper
          #  tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
          #  rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis fermentum
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

          #  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
          #  nibh id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis
          #  erat dolor. rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis
          #  fermentum
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects multiple prefixes (js/c comments)', ->
      text = '''
        // Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
        et enim eu orci tincidunt adipiscing
        aliquam ligula.
      '''

      res = '''
        // Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida et
        // enim eu orci tincidunt adipiscing aliquam ligula.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly handles * prefix', ->
      text = '''
        * Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

          * soidjfiojsoidj foi
      '''

      res = '''
        * Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida et
        * enim eu orci tincidunt adipiscing aliquam ligula.

          * soidjfiojsoidj foi
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res
