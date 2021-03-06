diameter = 800
svg = d3.select("body").append("svg")
    .attr("width", diameter)
    .attr("height", diameter)
plane = svg.append("g")
    .attr("id","plane")
    .attr("transform","translate(#{diameter/2.0},#{diameter/2.0}) scale(#{diameter/2.2},#{-diameter/2.2})")
    .style("stroke", "black")
    .style("stroke-width", "0.0005")
infinity = plane.append("circle")
    .attr("id","infinity")
    .attr("cx",0)
    .attr("cy",0)
    .attr("r",1)
    .style("fill", d3.hsl(180,0.5,1.0))
hyperbolic.Complex.setPrecision(7)
plane.transform = new hyperbolic.Isometry()

graph = null
tim = null

bisectId = d3.bisector( (d)-> d.id ).left
insertNode = (sn, tn)->
  sn.neighbors.splice(bisectId(sn.neighbors,tn),0,tn)
isNeighbor = (na,nb)->
  idx = bisectId(na.neighbors,nb)
  return na.neighbors[idx].id == nb.id

countCommon = (a, b)->
  i = j = 0
  count = 0
  while i < a.length and j < b.length
    if a[i].id == b[j].id
      count = count + 1
      i = i + 1
      j = j + 1
    else if a[i].id < b[j].id
      i = i + 1
    else:
      j = j + 1
  return count

#d3.json("data/facebook.json", (error, h) ->
d3.json("email-Eu-core.json", (error, h) ->
    if error
        throw error
    graph = h
    n = graph.nnodes
    graph.nodes = ( { id: i, degree: 0, neighbors: [] } for i in [0...n] )
    graph.links = []
    graph.max_degree = 0
    nedges = graph.edges.length/2
    for i in [0...nedges]
      si = graph.edges[2*i]
      ti = graph.edges[2*i+1]
      sn = graph.nodes[si]
      tn = graph.nodes[ti]
      sn.degree = sn.degree + 1
      tn.degree = tn.degree + 1
      #sn.neighbors.push(tn)
      insertNode(sn,tn)
      #tn.neighbors.push(sn)
      insertNode(tn,sn)
      if sn.degree > graph.max_degree
        graph.max_degree = sn.degree
      if tn.degree > graph.max_degree
        graph.max_degree = tn.degree
    bydegree = [0...n].sort( (a,b) -> (
      graph.nodes[b].degree - graph.nodes[a].degree)
    )
    for i in [0...n]
      graph.nodes[bydegree[i]].bydegree = i
    graph.bydegree = bydegree
    setNodes()
    addNodes()
)

circrect = (cx, cy, r, x, y, w, h)->
  h = h/2.0
  w = w/2.0
  cdx = Math.abs(cx - x)
  cdy = Math.abs(cy - y)
  if (cdx > (w + r))
    return false
  if (cdy > (h + r))
    return false
  if (cdx <= w)
    return true
  if (cdy <= h)
    return true
  co = (cdx - w)*(cdx - w) + (cdy - h)*(cdy - h)
  return (co <= (r*r))

setNodes = ->
  n = 7
  m = 3
  zero = new hyperbolic.Complex(0.0,0.0)
  polygons = []
  graph.R = 0
  count = 0
  graph.cR = hyperbolic.regularTilingRadius(n,m)
  console.log("hlen: #{graph.cR}")
  polygons = hyperbolic.regularTiling(n,m, (p)->
    count = count + 1
    graph.R = Math.max(graph.R, hyperbolic.distance(p.c,zero))
    return count > graph.nnodes
  )
  iHop = 1
  i = 0
  graph.cR = 0
  graph.quadtree = d3.quadtree()
    .extent([[-1, -1], [1,1]])
    .x( (d)-> d.x )
    .y( (d)-> d.y )
  while polygons[i].hop<iHop
    node = graph.nodes[graph.bydegree[i]]
    node.x = polygons[i].c.x
    node.y = polygons[i].c.y
    node.z = polygons[i].c
    graph.quadtree.add(node)
    graph.cR = Math.max(graph.cR, hyperbolic.distance(node.z,zero))
    i = i + 1
  console.log("R: #{graph.R}")
  maxCluster = (i,j)->
    coo = 0
    z = polygons[j].c
    node = graph.nodes[graph.bydegree[i]]
    [O, r] = hyperbolic.circle(z, graph.cR)
    #console.log([O,r])
    graph.quadtree.visit( (qnode, x1, y1, x2, y2)->
      if (!qnode.length)
        while true
          d = qnode.data
          if ((d.x - O.x)*(d.x - O.x) + (d.y - O.y)*(d.y - O.y))<=(r*r)
            #coo = coo + countCommon(d.neighbors,node.neighbors)
            if isNeighbor(node,d)
              coo = coo + 1
          break unless (qnode = qnode.next)
      return not circrect(O.x, O.y, r, (x1+x2)/2, (y1+y2)/2, (x2-x1), (y2-y1))
    )
    return coo

  while i < graph.nnodes
    if i % 100 == 0
      console.log(i)
    cmax = 0
    jmax = j = i
    hopi = polygons[i].hop
    while (j < graph.nnodes) and (polygons[j].hop <= hopi + 1)
      mc = maxCluster(i,j)
      if mc > cmax
        cmax = mc
        jmax = j
      j = j + 1
    temp = polygons[jmax]
    polygons[jmax] = polygons[i]
    polygons[i] = temp
    node = graph.nodes[graph.bydegree[i]]
    node.x = polygons[i].c.x
    node.y = polygons[i].c.y
    node.z = polygons[i].c
    graph.quadtree.add(node)
    graph.cR = Math.max(graph.cR, hyperbolic.distance(node.z,zero))
    i = i + 1

handleMouseOver = (d)->
  console.log("over")
  plane.select("#neighborhood").remove()
  g = plane.insert("g","#mark").attr("id","neighborhood") 
  links = g.selectAll(".link")
    .data(d.neighbors)
    .enter().append("path")
    .attr("class", "link")
    .attr("d", (dd)->
      return hyperbolic.svg.segment(d.z,dd.z)
    )
    .style("fill","none")


handleMouseOut = (d)->
  console.log("out")
  #plane.select("#neighborhood").remove()


addNodes = ->
  mark = plane.append("g").attr("id","mark")
  points = plane.selectAll(".node")
    .data(graph.nodes)
    .enter().append("circle")
    .attr("class", "node")
    .attrs( (d)->
      { cx: d.x, cy: d.y, r: 0.02}
    )
    .style("fill", (d)->
      d3.hsl(180,0.6,d.degree/graph.max_degree)
    )
    .on("click", (d)->
      transitionToCenter(d.z)
    )
    .on("mouseover", handleMouseOver)
    .on("mouseout", handleMouseOut)


addLinks = ->
  links = plane.selectAll(".link")
    .data(graph.links)
    .enter().append("path")
    .attr("class", "link")
    .attr("d", (d)->
      return hyperbolic.svg.segment(d.source.z,d.target.z)
    )
    .style("fill","none")

applyTransform = ->
  plane.select("#neighborhood").remove()
  for node in graph.nodes
    w = new hyperbolic.Complex(node.x, node.y)
    node.z = plane.transform.apply(w)
#  plane.selectAll(".link")
#    .attr("d", (d)->
#      return hyperbolic.svg.segment(d.source.z,d.target.z)
#    )
  plane.selectAll(".node")
    .attrs( (d)->
      { cx: d.z.x, cy: d.z.y, r: 0.02}
    )

transitionToCenter = (z)->
    last = 1.0
    tim = d3.timer( (elapsed)->
        t = elapsed/1000
        if t>1
            tim.stop()
        else
            prev = z.scale(last)
            last = 1.0-t
            next = z.scale(last)
            tr = hyperbolic.Isometry.translate(prev, next)
            plane.transform = tr.compose(plane.transform)
            applyTransform()
    )
