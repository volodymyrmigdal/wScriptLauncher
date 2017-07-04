( function _ScriptLauncher_s_() {

'use strict';

if( typeof module !== 'undefined' )
{
  require( 'wTools' );

  wTools.include( 'wProto' );
  wTools.include( 'wFiles' );
  wTools.include( 'wPath' );
  wTools.include( 'wConsequence' );
  wTools.include( 'wCopyable' );

  require( './aprovider/Abstract.s' );
  require( './aprovider/AdvancedMixin.s' );
  require( './aprovider/Chrome.ss' );
  require( './aprovider/Firefox.ss' );
  require( './aprovider/Electron.ss' );

  var pug = require( 'pug' );
}

//

var _ = wTools;
var Parent = null;
var Self = function wScriptLauncher( o )
{
  if( !( this instanceof Self ) )
  if( o instanceof Self )
  return o;
  else
  return new( _.routineJoin( Self, Self, arguments ) );
  return Self.prototype.init.apply( this,arguments );
}

Self.nameShort = 'ScriptLauncher';

//

function init( o )
{
  var self = this;

  _.instanceInit( self );

  Object.preventExtensions( self );

  // _.assert( o.filePath, 'wScriptLauncher expects mandatory option filePath' )

  if( o )
  self.copy( o );
}

//

function argsApply()
{
  var self = this;
  var args = _.appArgs();

  _.assert( arguments.length === 0 );

  args.map.filePath = args.map.filePath || args.subject;

  if( !args.scriptArgs.length )
  {
    logger.log( Self.helpGet() );
    return self;
  }

  args = args.map;

  self.copy
  ({
    headless : args.headless,
    filePath : args.filePath,
    platform : args.platform,
    terminatingAfter : args.terminatingAfter
  });

  if( self.terminatingAfter === null )
  self.terminatingAfter = self.headless;

  return self;
}

//

function launch()
{
  var self = this;

  self.launchDone.give()
  .seal( self )
  .ifNoErrorThen( self._scriptPrepare )
  .ifNoErrorThen( self._serverLaunch )
  .ifNoErrorThen( self._browserLaunch )
  .ifNoErrorThen( () => self._provider );

  if( self.handlingFeedback )
  self.launchDone
  .got( function ( err,got )
  {
    if( err )
    throw _.errLog( err );
    logger.log( got );
  });

  return self.launchDone;
}

//

function terminate()
{
  var self = this;

  if( self._provider )
  self._provider.terminate();

  if( self.server && self.server.isRunning )
  self.server.io.close( () => self.server.close() );
}

//

function _serverLaunch( )
{
  var self = this;
  var con = new wConsequence();
  var rootDir = _.pathResolve( __dirname, '../../..' );
  var script = _.fileProvider.fileRead( self.filePath );
  var express = require( 'express' );
  var app = express();
  self.server = require( 'http' ).createServer( app );
  self.server.io = require( 'socket.io' )( self.server );

  var statics = _.pathJoin( rootDir, 'staging/amid/launcher/static' );
  var modules = _.pathJoin( rootDir, 'node_modules' );

  app.use('/modules', express.static( modules ));
  app.use('/static', express.static( statics ));

  app.get( '/', function ( req, res )
  {
    res.sendFile( _.pathJoin( statics, 'index.html' ) );
  });

  app.get( '/script', function ( req, res )
  {
    res.send( script );
  });

  app.get( '/options', function ( req, res )
  {
    res.send({ terminatingAfter : self.terminatingAfter });
  });

  app.get( '/terminate', function ( req, res )
  {
    self.terminate();
  });

  self.server.io.on( 'connection', function( client )
  {
    client.on( 'join', function ( msg, reply )
    {
      if( self.verbosity >= 3 )
      logger.log( 'wLoggerToServer connected' );
      reply();
    });

    client.on ( 'log', function ( msg, reply )
    {
      if( self.verbosity >= 1 )
      logger.log( msg );
      reply();
    });

    // client.on( 'terminate', function ()
    // {
    //   if( self.terminatingAfter )
    //   self.terminate();
    // });

    // client.on( 'disconnect', function ()
    // {
    // })
  });


  self.server.listen( self.serverPort, function ()
  {
    if( self.verbosity >= 3 )
    logger.log( 'Server started on port ', self.serverPort );
    self.server.isRunning = true;
    con.give();
  });

  return con;
}

//

function _scriptPrepare()
{
  var self = this;
  var con = new wConsequence();

  if( !self.filePath )
  {
    self._script = function(){ logger.log( wScriptLauncher.helpGet() ) };
    con.give();
  }
  else
  {
    try
    {
      var code = _.fileProvider.fileRead( self.filePath );
      self._script = _.routineMake({ code : code, prependingReturn : 0 });
      con.give();
    }
    catch ( err )
    {
      con.error( err );
    }
  }

  return con;
}

//

function _browserLaunch()
{
  var self = this;
  var providerOptions =
  {
    url : `http://localhost:${self.serverPort}`,
    headless : self.headless,
    verbosity : self.verbosity
  }

  var provider = platformsMap[ self.platform ];
  if( provider === undefined )
  return self.launchDone.error( 'Requested browser is not supported.' );
  self._provider = provider( providerOptions );
  var result = self._provider.run();

  if( self._provider._process )
  self._provider._process.child.on( 'close', () => self.terminate() );

  return result;
}

//

var platformsMap =
{
  'firefox' : _.PlatformProvider.Firefox,
  'chrome' : _.PlatformProvider.Chrome,
  'electron' : _.PlatformProvider.Electron
}

//

function helpGet()
{
  var help =
  {
    'wScriptLauncher' : ' ',
    Usage :
    [
      'launcher [ path ]', 'launcher [ options ]',
      'Launcher expects path to script file as single argument or as option'
    ],
    Examples :
    [
      'launcher path/to/script.js',
      'launcher filePath : path/to/script.js platform : firefox headless : 0'
    ],
    Options :
    {
      filePath : 'Path to script file',
      platform : 'Target platform, that executes script file. Possible values : ' + _.mapOwnKeys( platformsMap ).join(),
      headless : 'Run without window. Possible values : 1/0',
    }
  }

  var strOptions =
  {
    levels : 3,
    wrap : 0,
    stringWrapper : '',
    multiline : 1
  };

  return _.toStr( help, strOptions );
}

// --
// relationship
// --

var Composes =
{
  filePath : null,
  platform : 'chrome',
  headless : true,
  verbosity : 1,
  handlingFeedback : 1,
  terminatingAfter : null
}

var Aggregates =
{
}

var Associates =
{
}

var Restricts =
{
  launchDone : new wConsequence(),
  server : null,
  serverPort : 3000,

  _script : null,
  _provider : null,
}

var Statics  =
{
  helpGet : helpGet
}

// --
// prototype
// --

var Proto =
{

  init : init,
  argsApply : argsApply,

  //

  launch : launch,
  terminate : terminate,

  _serverLaunch : _serverLaunch,
  _scriptPrepare : _scriptPrepare,
  _browserLaunch : _browserLaunch,


  //

  constructor : Self,
  Composes : Composes,
  Aggregates : Aggregates,
  Associates : Associates,
  Restricts : Restricts,
  Statics : Statics,

}

//

_.protoMake
({
  cls : Self,
  parent : Parent,
  extend : Proto,
});

wCopyable.mixin( Self );

//

if( typeof module !== 'undefined' )
module[ 'exports' ] = Self;
_global_[ Self.name ] = wTools[ Self.nameShort ] = Self;

//

if( typeof module !== 'undefined' && require.main === module )
{
  var launcher = wScriptLauncher({});
  launcher.argsApply();
  launcher.launch();
}

// if( typeof module !== 'undefined' && require.main === module )
// {
//   var args = _.appArgs();
//
//   if( !args.scriptArgs.length )
//   {
//     return logger.log( wScriptLauncher.helpGet() );
//   }
//   else if( !args.map )
//   {
//     args.map = { filePath : args.scriptArgs[ 0 ] }
//   }
//
//   args = args.map || {};
//
//
//
//   var launcher = wScriptLauncher
//   ({
//     headless : args.headless,
//     filePath : args.filePath,
//     platform : args.platform,
//     terminatingAfter : args.terminatingAfter
//   });
//
//   launcher.launch()
//   .got( function ( err,got )
//   {
//     if( err )
//     throw _.errLog( err );
//     logger.log( got );
//   });
//
// }

})();
