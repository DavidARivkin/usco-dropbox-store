getThumbNail:(projectName)=>
    myDeferred = Q.defer()
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
