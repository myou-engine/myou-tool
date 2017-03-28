
fs = require 'fs-extra'
os = require 'os'
unzip = require 'unzip'
{https} = require 'follow-redirects'
{join} = require 'path'
{spawnSync} = require 'child_process'
{HOME} = process.env
TEMP = os.tmpdir()
tmp_zip = join(TEMP, 'tmp_addon.zip')
unzip_out = join(TEMP, 'myou-blender-plugin-master')
addon_name = 'myou-blender-plugin-master'
config_dir = join(HOME, '.config', 'blender')

addon_url = 'https://github.com/myou-engine/myou-blender-plugin/archive/master.zip'

install = (versions=[]) ->
    versions = detect_versions versions
    if versions.length == 0
        return console.error 'ERROR: No Blender versions were detected. Please supply it as an argument.'
    fs.removeSync unzip_out
    # Downloading and unzipping master
    console.log 'Downloading add-on from GitHub...'
    https.get addon_url, (response) ->
        if response.statusCode!=200
            return console.error "Error #{response.statusCode} when downloading addon."
        if response.headers['content-type'] != 'application/zip'
            return console.error "Error when downloading addon: wrong file type."
        # For some reason this didn't work piping the download to unzip directly
        response.pipe(fs.createWriteStream tmp_zip).on 'close', ->
            fs.createReadStream(tmp_zip).pipe(unzip.Extract({ path: TEMP })).on 'close', ->
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
    # TODO: find proper paths in windows
    fs.ensureDirSync config_dir
    for v in fs.readdirSync config_dir
        if /\d\.\d\d/.test(v) and v not in versions
            versions.push v

    # detect versions from temp files
    # TODO: test locked files in windows and ignore them
    for fname in fs.readdirSync TEMP when /\.blend$/.test fname
        buf = new Buffer(12)
        f = fs.openSync join(TEMP, fname), 'r'
        fs.readSync f, buf, 0, 12
        fs.closeSync f
        head = buf+''
        if /^BLENDER..\d\d\d/.test head
            v = head[9]+'.'+head[10...]
            if v not in versions
                versions.push v

    # detect versions from installed binaries
    # TODO: find windows binaries in program files
    s = spawnSync 'blender', ['--version']
    if not s.error?
        v = s.stdout[8...12]+''
        if v not in versions
            versions.push v
    return versions

copy_files = (versions) ->
    console.log 'Copying files...'
    for v in versions
        dest = join(config_dir, v, 'scripts', 'addons', addon_name)
        fs.ensureDirSync dest
        fs.copySync unzip_out, dest

    console.log 'The addon has been installed for the following Blender versions:'
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
