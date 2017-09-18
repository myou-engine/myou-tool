
{join, resolve, basename} = require 'path'
readline = require 'readline'
{spawnSync} = require 'child_process'
fs = require 'fs-extra'
valid = require 'validate-npm-package-license'

init = (args) ->
    directory = resolve '.'
    if args[0]
        directory = join directory, args[0]
    dirname = basename directory
    pkg_path = join(directory, 'package.json')
    if not fs.existsSync pkg_path
        console.log """No package.json found. We'll generate one for you.
        See `npm help json` for documentation about fields in package.json."""

        ask_questions [
            {q: 'Name of the package?', def: dirname, key: 'name'}
            {q: 'Version?', def: '0.1.0', key: 'version'}
            {q: 'Description?', def: '', key: 'description'}
            {q: 'Git repository?', def: undefined, key: 'repository'}
            {q: 'Keywords?', def: undefined, key: 'keywords'}
            {q: 'Author?', def: '', key: 'author'}
            {q: 'License?', def: 'ISC', key: 'license', validate: (v) ->
                {spdx, warnings, inFile, unlicensed} = valid v
                if warnings?
                    console.warn warnings.join('\n')
                return spdx or unlicensed or inFile
            }
        ], (answers) ->
            answers.main = 'init.coffee'
            answers.scripts = {start: 'myou-tool serve webpack -w'}
            if answers.repository?
                answers.repository = {type: 'git', url: answers.repository}
            if answers.keywords?
                answers.keywords = answers.keywords.replace(/[, ]+/g, ' ').split(' ')
            pkg = JSON.stringify(answers, null, 2)
            console.log 'About to write to', pkg_path
            console.log pkg, '\n'
            ask_questions [q: 'Is this ok?', def: 'yes', key: 'ok'], (answers) ->
                if answers.ok[0] == 'y'
                    fs.ensureDirSync directory
                    fs.writeFileSync pkg_path, pkg
                    install_packages(directory)
                else
                    console.error 'Aborted.'
                    process.exit()
    else install_packages(directory)

install_packages = (directory) ->
    packages = [
        'vmath'
        'myou-engine'
        'webpack'
        'coffee-script'
        'coffee-loader'
    ]
    process.chdir directory
    console.log "Installing the following modules...", '\n    '+packages.join('\n    ')
    spawnSync 'npm', ['install', '--save'].concat(packages), {stdio: 'inherit', shell: true}
    console.log """If you want to install any other package,
    use `npm install <pkg> --save` to install it and
    save it as a dependency in the package.json file"""
    copy_template(directory)


copy_template = (directory) ->
    console.log "Copying files of only template currently available: 'simple'"
    fs.copySync join(__dirname,'..','templates','simple'), directory, {
        filter: (orig, dest) ->
            name = dest[directory.length+1...]
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
    process.exit()

rl = null
ask_questions = (questions, callback, answers={}, i=0) ->
    if not rl?
        rl = readline.createInterface input: process.stdin, output: process.stdout
    if questions[i]?
        {q, def, key, validate=->true} = questions[i]
        rl.question "#{q} [#{def or ''}] ", (ans) ->
            if validate(ans or def)
                answers[key] = ans or def
                i++
            ask_questions questions, callback, answers, i
    else
        callback(answers)
    return

module.exports = {init}
