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
      d = Q.defer()
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
    d = Q.defer()
    
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
    
    d = Q.defer()
    
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
