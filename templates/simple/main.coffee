
MyouEngine = require 'myou-engine'

# Configure and create the engine instance
canvas = MyouEngine.create_full_window_canvas()
myou = new MyouEngine.Myou canvas,
    # data_dir is the path to the exported scenes,
    # relative to the HTML file.
    data_dir: 'data',

# Load the scene called "Scene", its objects and enable it
myou.load_scene('Scene').then (scene) ->
    # At this point, the scene has loaded but not the meshes, textures, etc.
    # We must call scene.load to tell which things we want to load.
    return scene.load 'visible', 'physics'
.then (scene) ->
    # This part will only run after objects have loaded.
    # At this point we can enable rendering and physics at the same time.
    # Otherwise we would have a black screen.
    scene.enable 'render', 'physics'
    # If we ran this line before things have loaded, things would pop out
    # and fall unpredictably.

# Convenience variables for console access
# They have $ in the name to avoid using them by mistake elsewhere
window.$myou = myou
window.$MyouEngine = MyouEngine
window.$vmath = require 'vmath'
