# [http://github.com/TrevorBurnham/connect-assets](http://github.com/TrevorBurnham/connect-assets)

fs      = require 'fs'
path    = require 'path'
{parse} = require 'url'

cache = {}
libs = {}

module.exports = (options = {}) ->
  src = options.src ? 'assets'
  (req, res, next) ->
    return next() unless req.method is 'GET'
    targetPath = path.join src, parse(req.url).pathname
    fs.stat targetPath, (err, stats) ->
      # if the file exists, serve it
      return serveRaw req, res, next, {stats, targetPath} unless err
      # if the file doesn't exist, see if it can be compiled
      for ext, compiler of compilers
        if compiler.match.test targetPath
          return serveCompiled req, res, next, {compiler, ext, targetPath}
      # otherwise, pass the request up the Connect stack
      next()

serveRaw = (req, res, next, {stats, targetPath}) ->
  if cache[targetPath]?.mtime is stats.mtime
    return res.end cache.str
  fs.readFile targetPath, 'utf8', (err, str) ->
    next err if err
    cache[targetPath] = {mtime: stats.mtime, str}
    res.end str

serveCompiled = (req, res, next, {compiler, ext, targetPath}) ->
  srcPath = targetPath.replace(compiler.match, ".#{ext}")
  fs.stat srcPath, (err, stats) ->
    next err if err
    if cache[targetPath]?.mtime is stats.mtime
      return res.end cache.str
    compiler.compile srcPath, (err, str) ->
      next err if err
      cache[targetPath] = {mtime: stats.mtime, str}
      res.end str

compilers =
  coffee:
    match: /\.js$/
    compile: (filepath, callback) ->
      libs.CoffeeScript or= require 'coffee-script'
      fs.readFile filepath, 'utf8', (err, str) ->
        return callback err if err
        try
          callback null, libs.CoffeeScript.compile str
        catch e
          callback e
  styl:
    match: /\.css$/
    compile: (filepath, callback) ->
      libs.stylus or= require 'stylus'
      fs.readFile filepath, 'utf8', (err, str) ->
        libs.stylus.render str, filename: path.basename(filepath), callback