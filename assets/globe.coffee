Globe =
  loadResources: (textures, xhr, allSucceeded) ->
    pendingTextures = textures
    pendingXHR = xhr
    completeTextures = {}
    completeXHR = {}

    success = (pending, complete, name) ->
      (result) ->
        delete pending[name]
        complete[name] = result
        if Object.keys(pendingTextures).length == 0 && Object.keys(pendingXHR).length == 0
          allSucceeded(completeTextures, completeXHR)

    textureLoader = new THREE.TextureLoader()
    for name, url of pendingTextures
      textureLoader.load url, success(pendingTextures, completeTextures, name)

    xhrLoader = new THREE.XHRLoader()
    for name, url of pendingXHR
      xhrLoader.load url, success(pendingXHR, completeXHR, name)

  loadEverything: (success) ->
    textures =
      surface: 'images/mars_filtered_2500.jpg'
      bump: 'images/mars_elevation_2500.jpg'
      pinHead: 'images/circle.png'
      pinHeadMine: 'images/circle_b.png'

    xhr =
      pins: 'pins.csv'

    Globe.loadResources(textures, xhr, success)

  init: (container, textures, xhr) ->
    globe =
      interaction:
        mouse: Globe.vec2(0, 0)
        targetRotation: Globe.vec2(Math.PI * 5/16, Math.PI * 1/12)
        rotation: Globe.vec2(Math.PI * (5/16 - 1), 0)
        distance: 10000
      gl: Globe.setupScene(800, 800, textures)
      container: container

    globe.container.appendChild(globe.gl.renderer.domElement)

    Globe.addEvents(globe, globe.interaction, globe.gl, globe.container)
    Globe.animate () -> Globe.render(globe.gl, globe.interaction)
    Globe.populatePins(globe.gl, xhr.pins)

    globe

  eventModes:
    rest: [
      ['container', 'mousemove', 'mouseMove']
      ['container', 'mousedown', 'dragStart']]
    dragging: [
      ['document', 'mousemove', 'dragMove']
      ['document', 'mouseup', 'dragStop']
      ['document', 'mouseexit', 'dragStop']]
    hoveringWithPin: []
 
  addEvents: (globe) ->
    globe.interaction.events =
      mouseMove: (e) ->
        pin = Globe.raycastPin(globe.gl, Globe.containerOffset(globe.container, e))
        if pin?
          if pin.fingerprint == Globe.myFingerprint()
            Globe.setCaption('My fingerprint: ' + pin.fingerprint)
          else
            Globe.setCaption('Pin placed by: ' + pin.fingerprint)
        else
          Globe.setCaption()

      dragStart: (e) ->
        globe.container.style.cursor = 'grabbing'
        globe.interaction.mouse = Globe.containerOffset(globe.container, e)
        caption.textContent = null
        Globe.transitionMode(globe, 'dragging')

      dragMove: (e) ->
        prevMouse = globe.interaction.mouse
        globe.interaction.mouse = Globe.containerOffset(globe.container, e)
        ds = globe.interaction.mouse.clone().sub(prevMouse).multiply(Globe.vec2(-1, 1))
        globe.interaction.targetRotation.add(ds.multiplyScalar(0.004))
        globe.interaction.targetRotation.setY(Globe.clamp([-Math.PI/2, Math.PI/2], globe.interaction.targetRotation.y))

      dragStop: (e) ->
        globe.container.style.cursor = null
        Globe.transitionMode(globe, 'rest')

    Globe.transitionMode(globe, 'rest')

  transitionMode: (globe, mode) ->
    targets = {container: globe.container, document: document}

    if globe.interaction.mode?
      for binding in Globe.eventModes[globe.interaction.mode]
        targets[binding[0]].removeEventListener(binding[1], globe.interaction.events[binding[2]])

    for binding in Globe.eventModes[mode]
      targets[binding[0]].addEventListener(binding[1], globe.interaction.events[binding[2]])

    globe.interaction.mode = mode

  setCaption: (text) ->
    caption = document.getElementById('caption')
    caption.textContent = text

  setupScene: (w, h, textures) ->
    gl =
      scene: new THREE.Scene()
      camera: new THREE.PerspectiveCamera(30, w/h, 1, 10000)
      renderer: new THREE.WebGLRenderer()
      textures: textures
      pinTemplate:
        line: new THREE.Line new THREE.Geometry(),
          new THREE.LineBasicMaterial
            color: 0xffffff
            opacity: 1
        sprite: new THREE.Sprite(
          new THREE.SpriteMaterial
            color: 0xffffff)
      pins: new THREE.Object3D()

    gl.renderer.setSize(w, h)
    
    gl.pinTemplate.line.geometry.vertices = [Globe.vec3(0, 0, 0), Globe.vec3(0, 0, 0)]
    gl.pinTemplate.sprite.scale.set(3, 3, 0)
    gl.pinTemplate.sprite.material.map = gl.textures.pinHead

    gl.pins.fingerprints = {}

    material = new THREE.MeshPhongMaterial
      map: gl.textures.surface
      bumpMap: gl.textures.bump
      color: 0xffffff
      ambient: 0xffffff
      specular: 0x9c521d
      shininess: 1
      bumpScale: 5
      shading: THREE.SmoothShading

    geometry = new THREE.SphereGeometry(200, 40, 30)
    gl.mesh = new THREE.Mesh(geometry, material)
    gl.scene.add(gl.mesh)

    gl.lights =
      ambient: new THREE.AmbientLight(0x222222)
      directional: new THREE.DirectionalLight(0xffffff, 1)

    gl.lights.directional.position.set(1, 0, 1).normalize()
    gl.scene.add(gl.lights.ambient, gl.lights.directional, gl.pins)

    gl

  makePin: (gl, mine) ->
    pin = new THREE.Object3D()
    pin.line = gl.pinTemplate.line.clone()
    pin.line.geometry = gl.pinTemplate.line.geometry.clone()
    pin.sprite = gl.pinTemplate.sprite.clone()
    pin.sprite.material = gl.pinTemplate.sprite.material.clone()
    if mine
      pin.sprite.material.map = gl.textures.pinHeadMine
      pin.sprite.scale.set(5, 5, 0)
    pin.add(pin.line, pin.sprite)

  positionPin: (gl, pin, pos) ->
    verts = pin.line.geometry.vertices
    verts[0].copy(Globe.vec3(0, 0, 0))
    verts[1].copy(pos.normalize().multiplyScalar(8))
    pin.line.geometry.verticesNeedUpdate = true
    pin.sprite.position.copy(pos.normalize().multiplyScalar(9))
    pin.position.copy(pos.normalize().multiplyScalar(200))

  animate: (render) ->
    requestAnimationFrame () -> Globe.animate(render)
    render()

  render: (gl, i) ->
    i.rotation.add(i.targetRotation.clone().sub(i.rotation).multiplyScalar(0.05))
    i.distance += (850 - i.distance) * 0.2

    axis = Globe.vec3(0, 1, 0)

    gl.camera.position.copy(
      Globe.vec3(0, 0, 1)
        .applyAxisAngle(axis, i.rotation.x)
        .multiplyScalar(Math.cos(i.rotation.y))
        .setY(Math.sin(i.rotation.y))
        .multiplyScalar(i.distance))

    gl.lights.directional.position.copy(
      gl.camera.position.clone()
        .applyAxisAngle(axis, Math.PI / 4).normalize())

    gl.camera.lookAt(Globe.vec3(0, 0, 0))
    gl.renderer.render(gl.scene, gl.camera)

  glMouse: (mouse) ->
    mouse.clone()
      .multiplyScalar(2/800)
      .addScalar(-1)
      .multiply(Globe.vec2(1, -1))

  rayDirection: (gl, mouse) ->
    glmouse = Globe.glMouse(mouse)
    Globe.vec3(glmouse.x, glmouse.y, 0)
      .unproject(gl.camera)
      .sub(gl.camera.position)
      .normalize()

  raycast: (gl, mouse) ->
    direction = Globe.rayDirection(gl, mouse)

    raycaster = new THREE.Raycaster()
    raycaster.set(gl.camera.position, direction)
    hits = raycaster.intersectObject(gl.mesh, false)

    if hits.length > 0
      hits[0].point
    else
      null

  raycastPin: (gl, mouse) ->
    direction = Globe.rayDirection(gl, mouse)

    raycaster = new THREE.Raycaster()
    raycaster.set(gl.camera.position, direction)
    raycaster.linePrecision = 10

    objs = gl.pins.children.map (pin) ->  pin.line
    objs.push(gl.mesh)
    hits = raycaster.intersectObjects(objs, false)
    
    if hits.length > 0 && hits[0].object.type == 'Line'
      hits[0].object.parent
    else
      null

  vectorToLatLon: (pos) ->
    lat: (Math.atan2(Math.sqrt(pos.x*pos.x + pos.z*pos.z), -pos.y) - Math.PI/2) * 180/Math.PI
    lon: -Math.atan2(pos.z, pos.x) * 180/Math.PI

  latLonToVector: (lat, lon) ->
    x = lon * Math.PI/180 + Math.PI/2
    y = lat * Math.PI/180

    Globe.vec3(0, 0, 1)
      .applyAxisAngle(Globe.vec3(0, 1, 0), x)
      .multiplyScalar(Math.cos(y))
      .setY(Math.sin(y))
  
  containerOffset: (container, e) ->
    Globe.vec2(
      e.clientX - container.offsetLeft
      e.clientY - container.offsetTop)

  vec3: (x, y, z) ->
    new THREE.Vector3(x, y, z)

  vec2: (x, y) ->
    new THREE.Vector2(x, y)

  clamp: (limits, x) ->
    limits = [limits[1], limits[0]] if limits[1] < limits[0]
    if x < limits[0]
      limits[0]
    else if x > limits[1]
      limits[1]
    else
      x

  myFingerprint: () ->
    el = document.getElementById('my-fingerprint')
    if el?
      el.getAttribute('value')
    else
      null

  populatePins: (gl, csv) ->
    myFingerprint = Globe.myFingerprint()
    placedMine = false

    for props in Globe.parseCSV(csv)
      mine = props.fingerprint == myFingerprint
      placedMine = true if mine

      pin = Globe.makePin(gl, mine)
      pin.fingerprint = props.fingerprint

      Globe.positionPin gl, pin,
        Globe.latLonToVector(props.lat, props.lon)

      gl.pins.fingerprints[pin.fingerprint] = pin
      gl.pins.add(pin)

    document.getElementById('pinwell').classList.remove('empty') if !placedMine

  get: (path, success, error) ->
    req = new XMLHttpRequest()
    req.onload = (e) -> success(req.responseText)
    req.onerror = (e) -> error(req)
    
    req.open('get', path)
    req.send()

  parseCSV: (text) ->
    text.split('\n')
      .filter (line) -> line.length > 0
      .map (line) -> line.split(',')
      .map (row) ->
        fingerprint: row[0]
        lat: parseFloat(row[1])
        lon: parseFloat(row[2])

window.Globe = Globe
