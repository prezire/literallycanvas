window.LC = window.LC ? {}


coordsForEvent = ($el, e) ->
  t = e.originalEvent.changedTouches[0]
  p = $el.position()
  return [t.clientX - p.left, t.clientY - p.top]


$.fn.literallycanvas = ->

  $c = @find('canvas')
  c = $c.get(0)

  lc = new LC.LiterallyCanvas(c)
  tb = new LC.Toolbar(lc, @find('.toolbar'))

  $c.mousedown (e) =>
    document.onselectstart = -> false # disable selection while dragging
    lc.beginDraw(e.offsetX, e.offsetY)

  $c.mousemove (e) =>
    lc.continueDraw(e.offsetX, e.offsetY)

  $c.mouseup (e) =>
    document.onselectstart = -> true # disable selection while dragging
    lc.endDraw(e.offsetX, e.offsetY)

  $c.mouseout (e) =>
    lc.endDraw(e.offsetX, e.offsetY)

  $c.bind 'touchstart', (e) ->
    e.preventDefault()
    coords = coordsForEvent($c, e)
    if e.originalEvent.touches.length == 1
      lc.beginDraw(coords[0], coords[1])
    else
      lc.continueDraw(coords[0], coords[1])

  $c.bind 'touchmove', (e) ->
    e.preventDefault()
    coords = coordsForEvent($c, e)
    lc.continueDraw(coords[0], coords[1])

  $c.bind 'touchend', (e) ->
    e.preventDefault()
    return unless e.originalEvent.touches.length == 0
    coords = coordsForEvent($c, e)
    lc.endDraw(coords[0], coords[1])

  $c.bind 'touchcancel', (e) ->
    e.preventDefault()
    return unless e.originalEvent.touches.length == 0
    coords = coordsForEvent($c, e)
    lc.endDraw(coords[0], coords[1])

  $(document).keydown (e) ->
    switch e.which
      when 37 then lc.pan -10, 0
      when 38 then lc.pan 0, -10
      when 39 then lc.pan 10, 0
      when 40 then lc.pan 0, 10

    lc.repaint()

class LC.LiterallyCanvasState

  constructor: ->
    @strokeColor = 'rgba(0, 0, 0, 0.9)'
    @strokeWidth = 5

  makePoint: (x, y) -> new LC.Point(x, y, @strokeWidth, @strokeColor)


class LC.LiterallyCanvas

  constructor: (@canvas) ->
    @state = new LC.LiterallyCanvasState()

    @$canvas = $(@canvas)
    @ctx = @canvas.getContext('2d')
    $(@canvas).css('background-color', '#eee')
    @shapes = []
    @isDrawing = false
    @position = {x: 0, y: 0}
    @repaint()

  beginDraw: (x, y) ->
    if @isDrawing
      @saveShape()
    
    x = x - @position.x
    y = y - @position.y
    @isDrawing = true
    @currentShape = new LC.LinePathShape(@state)
    @currentShape.addPoint(x, y)
    @currentShape.drawLatest(@ctx)

  continueDraw: (x, y) ->
    return unless @isDrawing
    x = x - @position.x
    y = y - @position.y
    @currentShape.addPoint(x, y)
    @repaint()

  endDraw: (x, y) ->
    return unless @isDrawing
    x = x - @position.x
    y = y - @position.y
    @isDrawing = false
    @currentShape.addPoint(x, y)
    @saveShape()

  saveShape: ->
    @shapes.push(@currentShape)
    @currentShape = undefined
    @repaint()

  pan: (x, y) ->
    # Subtract because we are moving the viewport
    @position.x = @position.x - x
    @position.y = @position.y - y

  repaint: ->
    @ctx.clearRect(0, 0, @canvas.width, @canvas.height)
    @ctx.save()
    @ctx.translate @position.x, @position.y
    _.each @shapes, (s) =>
      s.draw(@ctx)
    if @isDrawing then @currentShape.draw(@ctx)
    @ctx.restore()

  clear: ->
    @undoStack.push(@shapes)
    @shapes = []
    @repaint()

  undo: ->
    @shapes = _.initial(@shapes)
    @repaint()

  redo: ->
 

class LC.LinePathShape
  constructor: (@lcState) ->
    @points = []

  addPoint: (x, y) ->
    @points.push(@lcState.makePoint(x, y))
    @smoothedPoints = LC.bspline(LC.bspline(LC.bspline(@points)))

  draw: (ctx) ->
    return unless @smoothedPoints.length
    fp = @smoothedPoints[0]
    lp = _.last(@smoothedPoints)

    _.each [fp, lp], (p) ->
      ctx.beginPath()
      ctx.fillStyle = p.color
      ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2)
      ctx.fill()
      ctx.closePath()

    ctx.beginPath()
    ctx.moveTo(fp.x, fp.y)

    _.each _.rest(@smoothedPoints), (p) ->
      ctx.strokeStyle = p.color
      ctx.lineWidth = p.size
      ctx.lineTo(p.x, p.y)
    ctx.stroke()
    ctx.closePath()

  drawLatest: (ctx) ->
    pair = _.last(@points, 2)
    return unless pair.length > 1
    ctx.beginPath()
    ctx.strokeStyle = pair[1].color
    ctx.lineWidth = pair[1].size
    ctx.moveTo(pair[0].x, pair[0].y)
    ctx.lineTo(pair[1].x, pair[1].y)
    ctx.stroke()


class LC.Point
  constructor: (@x, @y, @size, @color) ->
  lastPoint: -> this
  draw: (ctx) -> console.log 'draw point', @x, @y, @size, @color
