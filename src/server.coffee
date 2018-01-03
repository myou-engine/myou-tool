
http = require 'http'
url = require 'url'
mime = require 'mime'
stream = require 'stream'
fs = require 'fs'
{spawn} = require 'child_process'
path = require 'path'

root_dir = path.resolve './'

server = (cli_args) ->
    port = 8000
    while cli_args[0]?[0] == '-'
        switch cli_args[0]
            when '-p'
                [_, port] = cli_args.splice(0,2)
                # port is coerced to number where needed
                if not (1 <= port <= 65535)
                    return console.error "Invalid port '#{port}'"
            when '-r'
                [_, root_dir] = cli_args.splice(0,2)
                root_dir = path.resolve root_dir
                stat = fs.existsSync(root_dir) and fs.statSync(root_dir)
                if not stat.isDirectory?()
                    throw Error "Invalid root path"
            else
                return console.error "Unrecognized option: "+cli_args[0]

    # This server reads whole files and streams from RAM,
    # to avoid locking files in Windows
    # TODO: Limit by size, and/or detect non-Windows OS
    http_server = http.createServer (req, res) ->
        pathname = decodeURIComponent((url.parse req.url).pathname)
        console.log req.connection.remoteAddress, pathname
        pathl = []
        for p in pathname[1...].split('/')
            if p == '..'
                pathl.pop()
            else
                pathl.push p
        path = root_dir+'/'+pathl.join('/')
        status = 200
        headers = {}
        contents = ''
        try
            stat = fs.statSync path
            if stat.isDirectory() and path[path.length-1] == '/'
                path += 'index.html'
                if not fs.existsSync path
                    contents = make_index path[...-10]
            contents = contents or fs.readFileSync path
            headers['Content-Type'] = mime.lookup path
        catch e
            if e.code == 'ENOENT'
                contents = "<h1>404 File not found</h1>\n"
                status = 404
            else
                contents = "<h1>500 Internal server error</h1>\n"
                status = 500
                console.error e
            headers['Content-Type'] ='text/html'
        if req.headers.range?
            {start, end, content_range} =
                parse_range req.headers.range, contents.length
            contents = contents[start..end] # TODO: do this while reading file
            headers['Content-Range'] = content_range
            headers['Accept-Ranges'] = 'bytes'
            status = 206
        # Disable cache in all ways known to humankind. Probably overkill.
        headers['Expires'] = 'Wed, 21 Oct 2015 07:28:00 GMT'
        headers['Cache-Control'] ='no-cache, no-store, must-revalidate'
        headers['ETag'] = '"'+Math.random()+Math.random()+Math.random()+'"'
        headers['Age'] = 157680000
        headers['Content-Length'] = contents.length
        res.writeHead status, headers
        bufst = new stream.PassThrough()
        bufst.end contents
        bufst.pipe res

    http_server.listen port, '0.0.0.0', ->
        console.log 'Server created successfully in port: ' + port
        console.log 'Open in browser: http://127.0.0.1:'+port
        [cmd, args...] = cli_args
        if cmd?
            console.log "Running", cmd, args.join(' '), '...'
            p = spawn cmd, args, {stdio: 'inherit', shell: true}
            p.on 'close', (code) ->
                console.log "#{cmd} exited with code #{code}"

parse_range = (range, total) ->
    if not range?
        return {}
    parts = range.replace(/bytes=/, "").split("-")
    partialstart = parts[0]
    partialend = parts[1]

    start = parseInt(partialstart, 10);
    end = total-1
    if partialend
        end = parseInt(partialend, 10)

    content_range = 'bytes ' + start + '-' + end + '/' + total
    return {start, end, content_range}

make_index = (dir) ->
    files = for name in fs.readdirSync dir
        stat = fs.statSync dir+'/'+name
        {name, stat, is_dir: stat.isDirectory()}
    files.sort (a,b) ->
        adir = a.stat.isDirectory()
        bdir = b.stat.isDirectory()
        if a.is_dir == b.is_dir
            return a.name.localeCompare b.name
        return b.is_dir - a.is_dir
    files_html = for {name, stat, is_dir} in files
        if is_dir
            icon = '🗀'
            size = ''
            name += '/'
        else
            icon = '🗎'
            size = stat.size
        """<tr><td style="font-size: 120%; text-align:center;">#{icon}</td>
            <td><a href="#{enc_uri name}">#{esc_html name}</a></td>
            <td style="padding: 2px 5px 2px 20px;text-align: right;">
                #{size}
            </td>
            <td>#{stat.mtime}</td></tr>"""
    esc_dir = esc_html dir[1...]
    return """<!doctype html>
        <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width">
                <title>Index of #{esc_dir}</title>
            </head>
            <body>
                <h1>Index of #{esc_dir}</h1>
                <table>""" + files_html.join('\n') + """</table>
            </body>
        </html>"""

esc_html = (s) ->
    s.replace /[<>&"'`]/gm, (s) ->
        "&##{s.charCodeAt 0};"

enc_uri = (s) ->
    esc_html encodeURIComponent(s).replace '%2F', '/'

module.exports = {server}
