
fs = require 'fs-extra'
os = require 'os'
unzip = require 'unzip'
{https} = require 'follow-redirects'
{join} = require 'path'
{spawnSync} = require 'child_process'

TEMP = os.tmpdir()
tmp_zip = join(TEMP, 'tmp_addon.zip')
unzip_out = join(TEMP, 'myou-blender-add-on-master')
addon_name = 'myou-blender-add-on-master'

addon_url = '
    https://github.com/myou-engine/myou-blender-add-on/archive/master.zip'

if /^win/.test process.platform
    get_env = (key) ->
        key = key.toLowerCase()
        for k,v of process.env
            if k.toLowerCase() == key
                return v
        return ''
    config_dir = join(get_env('APPDATA'), 'Blender Foundation', 'Blender')
    binaries = []
    # TODO: should we look in other drives?
    if (program_files = get_env('PROGRAMFILES').replace(/ (x86)$/,''))
        binaries = [
            join(program_files, 'Blender Foundation', 'Blender', 'blender.exe'),
            join(program_files+' (x86)',
                'Blender Foundation', 'Blender', 'blender.exe')
        ]
else
    config_dir = join(process.env.HOME, '.config', 'blender')
    binaries = ['blender']
    # TODO: Also detect open blender instances

install = (versions=[]) ->
    versions = detect_versions versions
    if versions.length == 0
        return console.error 'ERROR: No Blender versions were detected.
            Please supply it as an argument.'
    fs.removeSync unzip_out
    # Downloading and unzipping master
    console.log 'Downloading add-on from GitHub...'
    https.get addon_url, (response) ->
        if response.statusCode!=200
            console.error "Error #{response.statusCode} when downloading addon."
            return
        if response.headers['content-type'] != 'application/zip'
            console.error "Error when downloading addon: wrong file type."
            return
        # For some reason this didn't work piping the download to unzip directly
        response.pipe(fs.createWriteStream tmp_zip).on 'close', ->
            fs.createReadStream(tmp_zip)
            .pipe(unzip.Extract({ path: TEMP })).on 'close', ->
                copy_files(versions)

detect_versions = (versions) ->
    console.log 'Detecting versions...'

    # remove letter from versions (e.g. 2.78a -> 2.78),
    # ensure format
    error = false
    versions = for v in versions
        if not /^\d\.\d\d\w?$/.test v
            error = true
            break
        v[...4]
    if error
        return console.error v+' is not a valid Blender version'

    # detect versions from config folders
    fs.ensureDirSync config_dir
    for v in fs.readdirSync config_dir
        if /^\d\.\d\d$/.test(v) and v not in versions
            versions.push v

    # detect versions from temp files
    # TODO: figure out how to get windows' TEMP in cygwin
    for fname in fs.readdirSync TEMP when (/\.blend$/i).test fname
        buf = new Buffer(12)
        try
            f = fs.openSync join(TEMP, fname), 'r'
            fs.readSync f, buf, 0, 12
            fs.closeSync f
        catch e
            continue
        head = buf+''
        if /^BLENDER..\d\d\d/.test head
            v = head[9]+'.'+head[10...]
            if v not in versions
                versions.push v

    # detect versions from installed binaries
    for bin in binaries
        s = spawnSync bin, ['--version']
        if not s.error?
            v = s.stdout[8...12]+''
            if /^\d\.\d\d$/.test(v) and v not in versions
                versions.push v
        return versions

copy_files = (versions) ->
    console.log 'Copying files...'
    for v in versions
        dest = join(config_dir, v, 'scripts', 'addons', addon_name)
        fs.ensureDirSync dest
        fs.copySync unzip_out, dest
        # Remove addon with old repo name
        old_dest = join(config_dir, v,
            'scripts', 'addons', 'myou-blender-plugin-master')
        if fs.existsSync old_dest
            fs.removeSync old_dest


    console.log \
        'The addon has been installed for the following Blender versions:'
    console.log versions.join('\n')
    console.log '''
    Remember to enable the add-on with the following steps:
        File -> User Preferences... -> Add-ons -> Game Engine ->
        Click the checkbox next to "Myou game engine" ->
        Save User Settings'''

    fs.removeSync unzip_out
    fs.removeSync tmp_zip
    return


module.exports = {install}
