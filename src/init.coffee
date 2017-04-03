
{join, resolve, basename} = require 'path'
readline = require 'readline'
{spawnSync} = require 'child_process'
fs = require 'fs-extra'

init = (args) ->
    cwd = resolve '.'
    if not fs.existsSync 'package.json'
        spawnSync 'npm', ['init'], {stdio: 'inherit', shell: true}
    packages = [
        'coffee-loader'
        'webpack'
        'myou-engine'
    ]
    console.log "Installing modules..."
    spawnSync 'npm', ['install', '--save'].concat(packages), {stdio: 'inherit', shell: true}

    console.log "Copying files of only template currently available: 'simple'"
    fs.copySync join(__dirname,'..','templates','simple'), cwd, {
        filter: (orig, dest) ->
            name = dest[cwd.length+1...]
            stat = fs.statSync orig
            exists = fs.existsSync dest
            if stat.isDirectory() and basename(orig) != 'node_modules'
                return true
            if exists
                console.warn "Warning: skipping #{name} because it exists."
                return false
            console.log name
            return true
    }

    # We want to ask the questions ourselves instead of the ones of npm init,
    # because some of the questions don't make sense (such as entry point),
    # we can add npm commands like run and test, and maybe some other
    # questions relevant to game dev.

#     dirname = basename cwd
#     ask_questions [
#         {q: 'Name of the package?', def: dirname, key: 'name'}
#     ], (answers) ->
#         console.log 'finished', answers

rl = null
ask_questions = (questions, callback, answers={}, i=0) ->
    if not rl?
        rl = readline.createInterface input: process.stdin, output: process.stdout
    if questions[i]?
        {q, def, key} = questions[i]
        rl.question "#{q} [#{def}] ", (ans) ->
            answers[key] = ans or def
            ask_questions questions, callback, answers, i+1
    else
        callback(answers)
    return

module.exports = {init}
