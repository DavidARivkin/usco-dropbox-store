'use strict'
detectEnv = require "composite-detect"
Q = require "q"
path = require "path"
#mime = require "mime"

#StoreBase = require 'usco-kernel/src/stores/storeBase'
#utils = require 'usco-kernel/src/utils'
#merge = utils.merge

if detectEnv.isModule
  Minilog=require("minilog")
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatClean).pipe(Minilog.backends.console)
  logger = Minilog('dropbox-store')

if detectEnv.isNode
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatColor).pipe(Minilog.backends.console)
  Dropbox = require("dropbox");

if detectEnv.isBrowser
  Minilog.pipe(Minilog.suggest).pipe(Minilog.backends.console.formatClean).pipe(Minilog.backends.console)
  logger = Minilog('dropbox-store')
  Dropbox = window.Dropbox

 
class DropBoxStore #extends StoreBase
  
  constructor:(options)->
    options = options or {}
    defaults = 
      name:"Dropbox"
      description: "Store to the Dropbox Cloud based storage: requires login"
      rootUri:"/"
      isDataDumpAllowed: false
      isLoginRequired:true
      showPaths:false
    #options = merge defaults, options
    #super options
    
    @loggedIn = false
    if detectEnv.isNode
      @client = new Dropbox.Client
        key: "your-key-here",
        secret: "your-secret-here"
    else
      @client = new Dropbox.Client
        key: "z6yrlcnlyrinlp6"
        sandbox: true
      @client.authDriver new Dropbox.AuthDriver.Redirect(rememberUser:true, useQuery:true)
    
  login:=>
    deferred = Q.defer()
      
    @client.authenticate (error, client)=>
      if error?
        logger.error("dropbox-store failed to logged in",error)
        return @formatError(error, deferred)
      logger.info("dropbox-store logged in")
      @loggedIn = true
      #localStorage.setItem("dropbox-store-loggedIn",true)
      deferred.resolve( @ ) 

    return deferred
      
  logout:=>
    deferred = Q.defer()
    @client.signOut (error)=>
      if error?
        return @formatError(error, deferred)
      logger.info("dropbox-store logged out")
      @loggedIn = false
      deferred.resolve( @ )
    return deferred
        
  ###-------------------file/folder manipulation methods----------------###  
  ###*
  * list all elements inside the given uri (non recursive)
  * @param {String} uri the folder whose content we want to list
  * @return {Object} a promise, that gets resolved with the content of the uri
  ###
  list:( uri )=>
    deferred = Q.defer()
    
    @client.readdir uri, (error, entries, folderStat, entriesStats)=>
      if error
        return @formatError(error, deferred)
      deferred.resolve(entries, folderStat, entriesStats)
    
    return deferred
  
  ###*
  * read the file at the given uri, return its content
  * @param {String} uri absolute uri of the file whose content we want
  * @param {String} encoding the encoding used to read the file
  * @return {Object} a defferred, that gets resolved with the content of file at the given uri
  ###
  read:( uri , encoding )=>
    encoding = encoding or 'utf8'
    deferred = Q.defer()
    
    options = options or {}
    
    ###
    onProgress= ( event )->
      if (event.lengthComputable)
        percentComplete = (event.loaded/event.total)*100
        logger.debug "percent", percentComplete
        deferred.notify( {"loaded":percentComplete, "total":event.total} )
    @client.onXhr.addListener(onProgress)
    @client.onXhr.removeListener(onProgress)
    var xhrListener = function(dbXhr) {
  dbXhr.xhr.upload.onprogress("progress", function(event) {
    // event.loaded bytes received, event.total bytes must be received
    reportProgress(event.loaded, event.total);
  });
  return true;  // otherwise, the XMLHttpRequest is canceled
};
client.onXhr.addListener(xhrListener);
    
    ###
    
    @client.readFile uri, options, (error, data)=>
      if error?
        return @formatError( error, deferred)
      deferred.resolve( data )
    
    return deferred
  
  ###*
  * write the file at the given uri, with the given data, using given mimetype
  * @param {String} uri absolute uri of the file we want to write (if the intermediate directories do not exist, they get created)
  * @param {String} data the content we want to write to the file
  * @param {String} type the mime-type to use
  * @return {Object} a deferred, that gets resolved with "true" if writing to the file was a success, the error in case of failure
  ###
  write:( uri, content, type, overwrite )=>
    type = type or 'utf8' #mime.charsets.lookup()
    overwrite = overwrite or true
    deferred = Q.defer()
    options = {}
    
    logger.debug "writing file #{uri} with content #{content}"
    
    @client.writeFile uri, content, options, (error, stat) =>
      if error
        return @formatError(error, deferred)
      
      logger.debug "writen file #{uri} with content #{content}"
      logger.debug  ("File saved as revision " + stat.versionTag)
      deferred.resolve( content )
      
    return deferred
    
  
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
    
    @client.move fromPath, toPath, (error)=>
      if error
        return @formatError(error, deferred)
      deferred.resolve( true )
    
    return deferred
  
  ###*
  * delete the file or folder at the given uri
  * @param {String} uri absolute uri of the file we want to write (if the intermediate directories do not exist, they get created)
  * @return {Object} a deferred, that gets resolved with "true" if deleting the file was a success, the error in case of failure
  ###
  delete:( uri )=>
    deferred = Q.defer()
    @client.remove uri, (error, userInfo)=>
      if error
        return @formatError(error, deferred)
      logger.debug "removed #{uri}"
      
      deferred.resolve( @ )
    return deferred    
    
  ###-------------------Helpers----------------###
  formatError:(error, deferred)->
    switch error.status
      when 401
        # If you're using dropbox.js, the only cause behind this error is that
        # the user token expired.
        # Get the user through the authentication flow again.
        error = new Error("Dropbox token expired") 
      when 404 
        # The file or folder you tried to access is not in the user's Dropbox.
        # Handling this error is specific to your application.
        error = new Error("Failed to find the specified file or folder") 
      when 507 
        # The user is over their Dropbox quota.
        # Tell them their Dropbox is full. Refreshing the page won't help.
        error = new Error("Dropbox quota exceeded") 
      when 503 
        # Too many API requests. Tell the user to try again later.
        # Long-term, optimize your code to use fewer API calls.
        error = new Error("Dropbox: too many requests") 
      when 400  
        error = new Error("Dropbox: bad input parameter") 
        # Bad input parameter
      when 403  
        # Bad OAuth request.
        error = new Error("Dropbox: bad oauth request") 
      when 405 
        # Request method not expected
        error = new Error("Dropbox: unexpected request method") 
      else
        error = new Error("Dropbox: uknown error") 
        # Caused by a bug in dropbox.js, in your application, or in Dropbox.
        # Tell the user an error occurred, ask them to refresh the page.
    deferred.reject(error)
  
  authCheck:()->
      getURLParameter=(paramName)->
        hash = window.location.hash
        params = hash.split("&")
        
        i = 0
        while i < params.length
          val = params[i].split("=")
          return unescape(val[1])  if val[0] is paramName
          i++
      urlAuthOk = getURLParameter("#access_token")
      logger.debug "dropboxStore got redirect param #{urlAuthOk}"
      authOk = localStorage.getItem("dropbox-store-loggedIn")
      logger.debug "dropboxStore got localstorage Param #{authOk}"

      if urlAuthOk?
        #appBaseUrl = window.location.protocol + '//' + window.location.host + window.location.pathname
        #window.history.replaceState('', '', appBaseUrl)   
        @login()  
      else if authOk?
        @login()
      else
        @loggedIn = false
    
module.exports = DropBoxStore
