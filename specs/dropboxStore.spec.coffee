'use strict'
path = require 'path'
fs = require 'fs'
LocalStore = require "../src/localStore"


deleteFolderRecursive = (uri)->
  if fs.existsSync(uri)
    fs.readdirSync(uri).forEach (file,index)->
      curPath = uri + path.sep + file
      if(fs.statSync(curPath).isDirectory())
        deleteFolderRecursive(curPath)
      else 
        fs.unlinkSync(curPath)
    fs.rmdirSync(uri)


describe "local store", ->
  localStore = null 
  
  beforeEach ->
    localStore = new LocalStore()
  
  afterEach ->
    testDir = path.resolve("./specs/data/TestFolder")
    outputDir = path.resolve("./specs/data/TestFolderFoo")
    if fs.existsSync( testDir )
      deleteFolderRecursive( testDir )
    if fs.existsSync( outputDir )
      deleteFolderRecursive( outputDir )
  
  it 'can list the contents of a directory', (done)->
    testUri = path.resolve("./specs/data/PeristalticPump")
    localStore.list( testUri )
    .then ( dirContents ) =>
      console.log "dirContents",dirContents
      expect( dirContents ).toEqual( [ 'nema.coffee', 'PeristalticPump.coffee', 'pump.coffee' ] )
      done()
    .fail ( error ) =>
      console.log "error", error
      expect(false).toBeTruthy error.message
      done()
      
      
  it 'can read the contents of a file', (done)->
    testUri = path.resolve("./specs/data/PeristalticPump/PeristalticPump.coffee")
    
    expContent = """include("nema.coffee")
include("pump.coffee")

@config = {
           explode:1, # 0 for assembled pump 1 for exploded view
           layout:0, # 1 for assembled , 0 for single print object
           lobes: 3, # number of rollers
           pipe_od: 5, # outside diameter of pipe
           pipe_id: 4, #inside diamter of pip
           roller_outer: 12, # outerside diameter of the roller
           wall_thickness:10 # thickness of the outer wall
           }
p = new Pump(@config)

assembly.add(p)
if @config.layout
  motor = new NemaMotor()
  motor.translate([0,0,-motor.motorBody_len])
  assembly.add(motor)

"""
    localStore.read( testUri )
    .then ( fileContents ) =>
      console.log "fileContents",fileContents
      expect( fileContents ).toEqual( expContent )
      done()
    .fail ( error ) =>
      console.log "error", error
      expect(false).toBeTruthy error.message
      done()
  
  it 'can save data to local file system', (done)->
    testUri = path.resolve("./specs/data/TestFolder/foo.coffee")
    inputContent = """#this is a test file """
    
    localStore.write( testUri, inputContent )
    .then ( result ) =>
      console.log "result",result
      obsContent = fs.readFileSync( testUri, 'utf8' )
      expect( obsContent ).toEqual( inputContent )
      done()
    .fail ( error ) =>
      console.log "error", error
      expect(false).toBeTruthy error.message
      done()
  
  it 'can move/rename folders', (done)->
    testUri = path.resolve("./specs/data/TestFolder")
    outputUri = path.resolve("./specs/data/TestFolderFoo")
    fs.mkdirSync(testUri)
    
    localStore.move( testUri, outputUri )
    .then ( result ) =>
      console.log "result",result
      movedFolderExists = fs.existsSync( outputUri )
      expect( movedFolderExists ).toBeTruthy()
      done()
    .fail ( error ) =>
      console.log "error", error
      expect(false).toBeTruthy error.message
      done()
  
  it 'can move/rename files', (done)->  
    testDir = path.resolve("./specs/data/TestFolder")
    testUri = path.resolve("./specs/data/TestFolder/fooFile.coffee")
    
    outputDir = path.resolve("./specs/data/TestFolderFoo")
    outputUri = path.resolve("./specs/data/TestFolderFoo/barFile.coffee")
    
    fs.mkdirSync(testDir)
    fs.writeFileSync(testUri, "some content")
    
    localStore.move( testUri, outputUri )
    .then ( result ) =>
      console.log "result",result
      movedFolderExists = fs.existsSync( outputUri )
      expect( movedFolderExists ).toBeTruthy()
      done()
    .fail ( error ) =>
      console.log "error", error
      expect(false).toBeTruthy error.message
      done()
    
  it 'can check if a folder is a project ', (done)->
    testUri = path.resolve("./specs/data/PeristalticPump")
    obsIsProject = localStore.isProject( testUri )
    
    expect( obsIsProject ).toBeTruthy()
    done()
