# Tests for the ShareDB compatible text type.

fs = require 'fs'
util = require 'util'
assert = require 'assert'

randomizer = require './randomizer'
{randomInt, randomWord} = randomizer
text = require '../src/text2'

readOp = (file) ->
  op = for c in JSON.parse file.shift()
    if typeof c is 'number'
      c
    else if c.i?
      c.i
    else
      {d:c.d.length}

  text.normalize op

text.generateRandomOp = (docStr) ->
  initial = docStr

  op = []
  expectedDoc = ''

  consume = (len) ->
    expectedDoc += docStr[...len]
    docStr = docStr[len..]

  addInsert = ->
    # Insert a random word from the list somewhere in the document
    skip = randomInt Math.min docStr.length, 5
    word = randomWord() + ' '

    op.push skip
    consume skip

    op.push word
    expectedDoc += word

  addDelete = ->
    skip = randomInt Math.min docStr.length, 5

    op.push skip
    consume skip

    length = randomInt Math.min docStr.length, 4
    op.push {d:length}
    docStr = docStr[length..]

  while docStr.length > 0
    # If the document is long, we'll bias it toward deletes
    chance = if initial.length > 100 then 3 else 2
    switch randomInt(chance)
      when 0 then addInsert()
      when 1, 2 then addDelete()
    
    if randomInt(7) is 0
      break

  # The code above will never insert at the end of the document. Its important to do that
  # sometimes.
  addInsert() if randomInt(10) == 0

  expectedDoc += docStr
  [text.normalize(op), expectedDoc]
 
text.generateRandomDoc = randomWord



describe 'text2', ->
  describe 'text-transform-tests.json', ->
    it 'should transform correctly', ->
      testData = fs.readFileSync(__dirname + '/text-transform-tests.json').toString().split('\n')

      while testData.length >= 4
        op = readOp testData
        otherOp = readOp testData
        type = testData.shift()
        expected = readOp testData

        result = text.transform op, otherOp, type

        assert.deepEqual result, expected

    it 'should compose without crashing', ->
      testData = fs.readFileSync(__dirname + '/text-transform-tests.json').toString().split('\n')

      while testData.length >= 4
        testData.shift()
        op1 = readOp testData
        testData.shift()
        op2 = readOp testData

        # nothing interesting is done with result... This test just makes sure compose runs
        # without crashing.
        result = text.compose(op1, op2)

  it 'should normalize sanely', ->
    assert.deepEqual [], text.normalize [0]
    assert.deepEqual [], text.normalize ['']
    assert.deepEqual [], text.normalize [{d:0}]

    assert.deepEqual [], text.normalize [1,1]
    assert.deepEqual [], text.normalize [2,0]
    assert.deepEqual ['a'], text.normalize ['a', 100]
    assert.deepEqual ['ab'], text.normalize ['a', 'b']
    assert.deepEqual ['ab'], text.normalize ['ab', '']
    assert.deepEqual ['ab'], text.normalize [0, 'a', 0, 'b', 0]
    assert.deepEqual ['a', 1, 'b'], text.normalize ['a', 1, 'b']

  describe '#transformCursor()', ->
    # This test was copied from https://github.com/josephg/libot/blob/master/test.c
    ins = [10, "oh hi"]
    del = [25, {d:20}]
    op = [10, 'oh hi', 10, {d:20}] # The previous ops composed together

    tc = (op, isOwn, cursor, expected) ->
      assert.deepEqual [expected, expected], text.transformCursor [cursor, cursor], op, isOwn
 
    it "shouldn't move a cursor at the start of the inserted text", ->
      tc op, false, 10, 10
  
    it "move a cursor at the start of the inserted text if its yours", ->
      tc ins, true, 10, 15
  
    it 'should move a character inside a deleted region to the start of the region', ->
      tc del, false, 25, 25
      tc del, false, 35, 25
      tc del, false, 45, 25

      tc del, true, 25, 25
      tc del, true, 35, 25
      tc del, true, 45, 25
  
    it "shouldn't effect cursors before the deleted region", ->
      tc del, false, 10, 10
  
    it "pulls back cursors past the end of the deleted region", ->
      tc del, false, 55, 35
  
    it "teleports your cursor to the end of the last insert or the delete", ->
      tc ins, true, 0, 15
      tc ins, true, 100, 15
      tc del, true, 0, 25
      tc del, true, 100, 25

    it "works with more complicated ops", ->
      tc op, false, 0, 0
      tc op, false, 100, 85
      tc op, false, 10, 10
      tc op, false, 11, 16
  
      tc op, false, 20, 25
      tc op, false, 30, 25
      tc op, false, 40, 25
      tc op, false, 41, 26

  it 'passes the randomizer tests', ->
    @slow 1500
    randomizer text

