'use strict'
detectEnv = require "composite-detect"
Q = require "q"
fs = require "fs"
path = require "path"
mime = require "mime"
dropbox = require 'dropbox'

StoreBase = require 'usco-kernel/src/stores/storeBase'
utils = require 'usco-kernel/src/utils'
merge = utils.merge

if detectEnv.isModule
  Minilog=require("minilog")
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatClean).pipe(Minilog.backends.console)
  logger = Minilog('dropbox-store')

if detectEnv.isNode
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatColor).pipe(Minilog.backends.console)

if detectEnv.isBrowser
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatClean).pipe(Minilog.backends.console)
  logger = Minilog('dropbox-store')

 
class DropBoxStore extends StoreBase
  
  constructor:(options)->
    options = options or {}
    defaults = 
      name:"Dropbox"
      description: "Store to the Dropbox Cloud based storage: requires login"
      rootUri:"/"
      isDataDumpAllowed: false
      isLoginRequired:true
      showPaths:false
    options = merge defaults, options
    super options
    
  login:=>
    try
      onLoginSucceeded=()=>
        localStorage.setItem("dropboxCon-auth",true)
        @loggedIn = true
        @_dispatchEvent("DropboxStore:loggedIn")
        
      onLoginFailed=(error)=>
        throw error
        
      loginPromise = @fs.authentificate()
      $.when(loginPromise).done(onLoginSucceeded)
                          .fail(onLoginFailed)
    catch error
      @_dispatchEvent("DropboxStore:loginFailed")
      
  logout:=>
    try
      onLogoutSucceeded=()=>
        localStorage.removeItem("dropboxCon-auth")
        @loggedIn = false
        @_dispatchEvent("DropboxStore:loggedOut")
      onLoginFailed=(error)=>
        throw error
        
      logoutPromise = @fs.signOut()
      $.when(logoutPromise).done(onLogoutSucceeded)
                          .fail(onLogoutFailed)
    
    catch error
      @_dispatchEvent("DropboxStore:logoutFailed")
  
  ###-------------------file/folder manipulation methods----------------###  
  
  ###*
  * list all elements inside the given uri (non recursive)
  * @param {String} uri the folder whose content we want to list
  * @return {Object} a promise, that gets resolved with the content of the uri
  ###
  list:( uri )=>
    deferred = Q.defer()
    
    return deferred.promise
  
  ###*
  * read the file at the given uri, return its content
  * @param {String} uri absolute uri of the file whose content we want
  * @param {String} encoding the encoding used to read the file
  * @return {Object} a promise, that gets resolved with the content of file at the given uri
  ###
  read:( uri , encoding )=>
    encoding = encoding or 'utf8'
    deferred = Q.defer()
    
    options = options or {}
    @_dbClient.readFile path,options, (error, data)=>
      if error
        @_formatError( error, deferred )
      deferred.resolve( data )
    
    return deferred.promise
  
  ###*
  * write the file at the given uri, with the given data, using given mimetype
  * @param {String} uri absolute uri of the file we want to write (if the intermediate directories do not exist, they get created)
  * @param {String} data the content we want to write to the file
  * @param {String} type the mime-type to use
  * @return {Object} a promise, that gets resolved with "true" if writing to the file was a success, the error in case of failure
  ###
  write:( uri, data, type, overwrite )=>
    type = type or 'utf8' #mime.charsets.lookup()
    overwrite = overwrite or true
    deferred = Q.defer()
    
    
    return deferred.promise
  
  ###*
  * move/rename the item at first uri to the second uri
  * @param {String} uri absolute uri of the source file or folder
  * @param {String} newuri absolute uri of the destination file or folder
  * @param {Boolean} whether to allow overwriting or not (defaults to false)
  * @return {Object} a promise, that gets resolved with "true" if moving/renaming the file was a success, the error in case of failure
  ###
  move:( uri, newUri , overwrite)=>
    overwrite = overwrite or false
    deferred = Q.defer()
    
    @_dbClient.move fromPath, toPath, (error)=>
      if error
        @_formatError(error, deferred)
      deferred.resolve( true )
    
    return deferred.promise
  
  
  delete:( uri )=>
    deferred = Q.defer()
    
    return deferred.promise
    
  ###-------------------Helpers----------------###
  
  ###*
  * checks if specified uri is the uri of a project: the folder needs to exist, and to contain a file with the same name as the folder + one of the "code extensions"
  * to qualitfy
  * @param {String} uri absolute uri of the path to check
  * @return {Object} "true" if given uri is a project, "false" otherwise
  ###
  isProject:( uri )=>
    if fs.existsSync( uri )
      stats = fs.statSync( uri )
      if stats.isDirectory()
        codeExtensions = ["coffee", "litcoffee", "js", "usco", "ultishape"] #TODO: REDUNDANT with modules! where to put this
        for ext in codeExtensions
          baseName = path.basename( uri )
          mainFile = path.join( uri, baseName + "." + ext )
          if fs.existsSync( mainFile )
            return true
    return false
  
  
  
  mv: (fromPath, toPath)=>
      d = $.Deferred()
      @client.move fromPath, toPath, (error)=>
        if error
          @formatError(error,d)
        d.resolve()
      return d.promise()
  
  #####---------------------- 
  setup:()->
    super
    
    getURLParameter=(paramName)->
      searchString = window.location.search.substring(1)
      i = undefined
      val = undefined
      params = searchString.split("&")
      i = 0
      while i < params.length
        val = params[i].split("=")
        return unescape(val[1])  if val[0] is paramName
        i++
      null
    urlAuthOk = getURLParameter("_dropboxjs_scope")
    authOk = localStorage.getItem("dropboxCon-auth")
    if urlAuthOk?
      @login()
      appBaseUrl = window.location.protocol + '//' + window.location.host + window.location.pathname
      window.history.replaceState('', '', appBaseUrl)     
    else
      if authOk?
        @login()
  
  listDir:( uri )=>
    uri = if uri? then @fs.absPath( uri, @rootUri ) else @rootUri
    d = $.Deferred()
    
    addFileInfo = (files, folderStats, filesStats)=>
      results = []
      for file, index in files
        filePath = @fs.join([uri, file])
        result = {
          name: file,
          path : filePath
        }
        if filesStats[index].isFolder
          result.type = 'folder'
        else
          result.type = 'file'
        results.push( result )
      d.resolve(results)
    
    @fs.readdir( uri ).done(addFileInfo)
    return d
  
  saveProject:( project, path )=> 
    super
    
    #@fs.mkdir(projectUri)
    
    for index, file of project.getFiles()
      fileName = file.name
      filePath = @fs.join([projectUri, fileName])
      ext = fileName.split('.').pop()
      content = file.content
      if ext == "png"
        #save thumbnail
        if content != ""
          dataURIComponents = content.split(',')
          mimeString = dataURIComponents[0].split(':')[1].split(';')[0]
          if(dataURIComponents[0].indexOf('base64') != -1)
            console.log "base64 v1"
            data =  atob(dataURIComponents[1])
            array = []
            for i in [0...data.length]
              array.push(data.charCodeAt(i))
            content = new Blob([new Uint8Array(array)], {type: 'image/png'})
          else
            console.log "other v2"
            byteString = unescape(dataURIComponents[1])
            length = byteString.length
            ab = new ArrayBuffer(length)
            ua = new Uint8Array(ab)
            for i in [0...length]
              ua[i] = byteString.charCodeAt(i)
      @fs.writefile(filePath, content, {toJson:false})
      #file.trigger("save")
    
    @_dispatchEvent( "project:saved",project )
  
  loadProject:( projectUri , silent=false)=>
    super
    
    projectName = projectUri.split(@fs.sep).pop()
    #projectUri = @fs.join([@rootUri, projectUri])
    project = new Project
        name : projectName
    project.dataStore = @
    
    d = $.Deferred()
    
    onProjectLoaded=()=>
      project._clearFlags()
      if not silent
        @_dispatchEvent("project:loaded",project)
      d.resolve(project)
    
    loadFiles=( filesList ) =>
      promises = []
      for fileName in filesList
        filePath = @fs.join( [projectUri, fileName] )
        promises.push( @fs.readfile( filePath ) )
      $.when.apply($, promises).done ()=>
        data = arguments
        for fileName, index in filesList #todo remove this second iteration
          project.addFile 
            name: fileName
            content: data[index]
        onProjectLoaded()
    
    @fs.readdir( projectUri ).done(loadFiles)
    return d
  
  deleteProject:( projectUri )=>
    #projectPath = @fs.join([@rootUri, projectName])
    #index = @projectsList.indexOf(projectName)
    #@projectsList.splice(index, 1)
    return @fs.rmdir( projectUri )
  
  renameProject:(oldName, newName)=>
    #move /rename project and its main file
    #index = @projectsList.indexOf(oldName)
    #@projectsList.splice(index, 1)
    #@projectsList.push(newName)      
    return @fs.mv(oldName, newName).done(@fs.mv("/#{newName}/#{oldName}.coffee","/#{newName}/#{newName}.coffee"))
  
  getProject:(projectName)=>
    #console.log "locating #{projectName} in @projectsList"
    #console.log @projectsList
    if projectName in @projectsList
      return @loadProject(projectName,true)
    else
      return null
  
  #helpers
  projectExists: ( uri )=>
    #checks if specified project /project uri exists
    uri = @fs.absPath( uri, @rootUri )
    return @fs.exists( uri )
  
  getThumbNail:(projectName)=>
    myDeferred = $.Deferred()
    deferred = @store._readFile( "/#{projectName}/.thumbnail.png",{arrayBuffer:true})
    
    parseBase64Png=( rawData)->
      #convert binary png to base64
      bytes = new Uint8Array(rawData)
      data = ''
      for i in [0...bytes.length]
        data += String.fromCharCode(bytes[i])
      data =   btoa(data)
      #crashes
      #data = btoa(String.fromCharCode.apply(null, ))
      base64src='data:image/png;base64,'+data
      myDeferred.resolve(base64src)

    deferred.done(parseBase64Png)
    return myDeferred
  
  deleteFile:( filePath )=>
    @fs.rmfile( filePath )
  
  _sourceFetchHandler:([store, projectName, path, deferred])=>
    #This method handles project/file content requests and returns appropriate data
    if store != "dropbox"
      return null
    console.log "handler recieved #{store}/#{projectName}/#{path}"
    result = ""
    if not projectName? and path?
      shortName = path
      #console.log "proj"
      #console.log @project
      file = @project.rootFolder.get(shortName)
      result = file.content
      result = "\n#{result}\n"
    else if projectName? and not path?
      console.log "will fetch project #{projectName}'s namespace"
      project = @getProject(projectName)
      console.log project
      namespaced = {}
      for index, file of project.rootFolder.models
        namespaced[file.name]=file.content
        
      namespaced = "#{projectName}={"
      for index, file of project.rootFolder.models
        namespaced += "#{file.name}:'#{file.content}'"
      namespaced+= "}"
      #namespaced = "#{projectName}="+JSON.stringify(namespaced)
      #namespaced = """#{projectName}=#{namespaced}"""
      result = namespaced
      
    else if projectName? and path?
      console.log "will fetch #{path} from #{projectName}"
      getContent=(project) =>
        #cache for faster access: TODO: clear cache
        @cachedProjects[projectName]=project
        file = project.rootFolder.get(path)
        
        #now we replace all "local" (internal to the project includes) with full path includes
        result = file.content
        result = result.replace /(?!\s*?#)(?:\s*?include\s*?)(?:\(?\"([\w\//:'%~+#-.*]+)\"\)?)/g, (match,matchInner) =>
          includeFull = matchInner.toString()
          return """\ninclude("dropbox:#{projectName}/#{includeFull}")\n"""
          
        result = "\n#{result}\n"
        deferred.resolve(result)
      
      if not (projectName of @cachedProjects)
        @loadProject(projectName,true).done(getContent)
      else 
        getContent(@cachedProjects[projectName])

    return result
    
module.exports = DropBoxStore
