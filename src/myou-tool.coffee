
version = require('../package.json').version

help_msg = """
myou-tool #{version}
Usage: myou-tool <command> [options]

Commands:

install addon   Installs or updates the Blender add-on. If it doesn't find the
                current Blender version, you can specify it as an additional
                argument, e.g.:
                    myou-tool install addon 2.78

init            Creates a new myou-engine based project in the specified
                directory or the current one. It should either be an empty
                directory or contain a NPM package with its corresponding
                package.json. It will show a list of basic templates to choose
                from. E.g.:
                    myou-tool init awesome_game

server          Creates a HTTP server for development in the current directory.
                Optionally you can pass a command and arguments, e.g.:
                    myou-tool server webpack --watch

                Open in a different port with -p option:
                    myou-tool server -p 8080 webpack --watch

                Serve a different path with the -r option.

                Add more subpaths with -r web_path=real_path

"""

###
electron        Runs the supplied HTML or JS file inside electron. E.g.:
                    myou-tool electron index.html
                    myou-tool electron build/app.js

nwjs            Runs the supplied HTML or JS file inside NW.js. E.g.:
                    myou-tool nwjs index.html
                    myou-tool nwjs build/app.js
###

show_help = ->
    console.warn help_msg

main = ->

    # TODO: search in help

    switch process.argv[2]
        when "install"
            {install} = require './install'
            [what='', versions...] = process.argv[3...]
            if /add-?on/.test what
                install(versions)
            else
                show_help()
        when "init"
            {init} = require './init'
            init process.argv[3...]
        when "server", "serve"
            {server} = require './server'
            server process.argv[3...]
        when undefined
            show_help()
        else
            console.error "Error: Unknown command"
            show_help()




main()
