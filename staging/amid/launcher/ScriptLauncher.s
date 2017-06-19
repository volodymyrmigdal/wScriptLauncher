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

  _.assert( o.filePath, 'wScriptLauncher expects mandatory option filePath' )

  if( o )
  self.copy( o );

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

  return self.launchDone;
}

//

function _serverLaunch( )
{
  var self = this;
  var con = new wConsequence();
  var rootDir = _.pathResolve( __dirname, '../../../' );
  var express = require( 'express' );
  var app = express();
  var server = require( 'http' ).createServer( app );
  var io = require( 'socket.io' )(server);

  app.set( "view engine", "pug" );
  app.set( "views", _.pathJoin( __dirname, 'template' ));
  app.use( express.static( rootDir ) );

  app.get( '/', function ( req, res )
  {
    res.render( 'base', { script : self._script } );
  });

  app.get('/launcher/*', function ( req, res )
  {
    res.sendFile( _.pathJoin( rootDir, req.params[ 0 ] ) );
  });

  io.on( 'connection', function( client )
  {
    client.on( 'join', function()
    {
      if( self.verbosity >= 3 )
      console.log( 'wLoggerToServer connected' );

      client.on ( 'log', function ( msg )
      {
        if( self.verbosity >= 1 )
        logger.log( msg );
      });
    });
  });

  server.listen( self.serverPort, function ()
  {
    if( self.verbosity >= 3 )
    console.log( 'Server started on port ', self.serverPort );
    con.give();
  });

  return con;
}

//

function _scriptPrepare()
{
  var self = this;
  var con = new wConsequence();

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
  return self._provider.run();
}

//


var platformsMap =
{
  'firefox' : _.PlatformProvider.Firefox,
  'chrome' : _.PlatformProvider.Chrome,
  'electron' : _.PlatformProvider.Electron
}

// --
// relationship
// --

var Composes =
{
  filePath : null,
  platform : 'chrome',
  headless : true,
  verbosity : 1
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
  serverPort : 3000,

  _script : null,
  _provider : null,
}

// --
// prototype
// --

var Proto =
{

  init : init,

  //

  launch : launch,

  _serverLaunch : _serverLaunch,
  _scriptPrepare : _scriptPrepare,
  _browserLaunch : _browserLaunch,


  //

  constructor : Self,
  Composes : Composes,
  Aggregates : Aggregates,
  Associates : Associates,
  Restricts : Restricts,

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

if( typeof module !== "undefined" && require.main === module )
{
  var args = _.appArgs();

  var launcher = wScriptLauncher
  ({
    headless : args.map.headless,
    filePath : args.map.filePath,
    platform : args.map.platform
  });

  launcher.launch()
  .got( function ( err,got )
  {
    if( err )
    throw _.errLog( err );
    console.log( got );
  });
}

})();