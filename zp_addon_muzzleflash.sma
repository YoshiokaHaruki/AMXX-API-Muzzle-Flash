new const PluginName[ ] =				"[API] Addon: MuzzleFlash";
new const PluginVersion[ ] =			"1.4";
new const PluginAuthor[ ] =				"Yoshioka Haruki";

/* ~ [ Includes ] ~ */
#include <amxmodx>
#include <fakemeta_util>
#include <api_muzzleflash>

/**
 * If ur server can't use Re modules, just comment out or delete this line
 */
#include <reapi>

#if defined _reapi_included
	#define ShowSpriteOnlyForOwner
#endif

#if !defined _reapi_included
	#include <hamsandwich>

	#define NULLENT							FM_NULLENT
	#define PDATA_SAFE						2

	#define get_entvar						pev
	#define set_entvar						set_pev

	// Looks like a bullshit XD
	#define set_entvar_string				set_pev_string

	#define var_impulse						pev_impulse
	#define var_frame						pev_frame
	#define var_classname					pev_classname
	#define var_playerclass					pev_playerclass
	#define var_rendermode					pev_rendermode
	#define var_rendercolor					pev_rendercolor
	#define var_renderamt					pev_renderamt
	#define var_scale						pev_scale
	#define var_owner						pev_owner
	#define var_aiment						pev_aiment
	#define var_body						pev_body
	#define var_framerate					pev_framerate
	#define var_nextthink					pev_nextthink
	#define var_flags						pev_flags
	#define var_yaw_speed					pev_yaw_speed
	#define var_pitch_speed					pev_pitch_speed
	#define var_ideal_yaw					pev_ideal_yaw

	#define rg_create_entity				fm_create_entity
	#define is_nullent(%0)					( %0 == NULLENT || pev_valid( %0 ) != PDATA_SAFE )
#endif

#if AMXX_VERSION_NUM <= 183
	#define MAX_NAME_LENGTH					32
	#define MAX_RESOURCE_PATH_LENGTH		64
#endif

/* ~ [ Plugin Settings ] ~ */
/**
 * Set 'false' if u don't needed Error Logs
 */
#define WriteErrorLogs						true
/**
 * Logs that will not affect the further operation of the plugin, where natives are used
 * NB! With this setting, you will not know in which plugin and on which line the error occurred
 * 
 * Comment out or delete this line, if u don't needed Safe Error Logs
 */
// #define UseSafeErrorLogs

new const PluginPrefix[ ] =					"[API:MuzzleFlash]";
new const EntityMuzzleFlashReference[ ] =	"env_sprite";
new const EntityMuzzleFlashClassname[ ] =	"ent_muzzleflash_x";

/* ~ [ Params ] ~ */
enum _: eMuzzleFlashData {
	eMuzzle_ClassName[ MAX_NAME_LENGTH ],
	eMuzzle_Sprite[ MAX_RESOURCE_PATH_LENGTH ],
	eMuzzle_Attachment,
	Float: eMuzzle_Scale,
	Float: eMuzzle_UpdateTime,
	Float: eMuzzle_FrameRateMlt,
	Float: eMuzzle_Color[ 3 ],
	Float: eMuzzle_Alpha,
	Float: eMuzzle_MaxFrames,
	eMuzzle_Flags
};
new Array: gl_arMuzzleFlashData;
new gl_iMuzzlesCount;

#if !defined _reapi_included
	new gl_iszAllocString_Muzzleflash;
#endif

/* ~ [ Macroses ] ~ */
#define IsNullString(%0)					bool: ( %0[ 0 ] == EOS )
#define IsArrayInvalid(%0)					( %0 == Invalid_Array || !ArraySize( %0 ) )

#define var_max_frame						var_yaw_speed // CEntity: env_sprite
#define var_last_time						var_pitch_speed // CEntity: env_sprite
#define var_update_frame					var_ideal_yaw // CEntity: env_sprite
#define var_sprite_flags					var_playerclass // CEntity: env_sprite

/* ~ [ AMX Mod X ] ~ */
public plugin_natives( )
{
	register_native( "zc_muzzle_init", "native_muzzle_init" );
	register_native( "zc_muzzle_clear", "native_muzzle_clear" );
	register_native( "zc_muzzle_get_property", "native_muzzle_get_property" );
	register_native( "zc_muzzle_set_property", "native_muzzle_set_property" );
	register_native( "zc_muzzle_find", "native_muzzle_find" );
	register_native( "zc_muzzle_draw", "native_muzzle_draw" );
	register_native( "zc_muzzle_destroy", "native_muzzle_destroy" );
}

public plugin_precache( )
{
	/* -> Array's <- */
	gl_arMuzzleFlashData = ArrayCreate( eMuzzleFlashData );

#if !defined _reapi_included
	/* -> Alloc String <- */
	gl_iszAllocString_Muzzleflash = engfunc( EngFunc_AllocString, EntityMuzzleFlashClassname );
#endif
}

public plugin_init( )
{
	register_plugin( PluginName, PluginVersion, PluginAuthor );

#if !defined _reapi_included
	/* -> HamSandwich <- */
	RegisterHam( Ham_Think, EntityMuzzleFlashReference, "CMuzzleFlash__Think", false );
#endif
}

/* ~ [ Other ] ~ */
public CMuzzleFlash__SpawnEntity( const pPlayer, const iMuzzleId, const aData[ ] )
{
	static const LOWER_LIMIT_OF_ENTITIES = 100;
	
	static iMaxEntities; if ( !iMaxEntities ) iMaxEntities = global_get( glb_maxEntities );
	if ( iMaxEntities - engfunc( EngFunc_NumberOfEntities ) <= LOWER_LIMIT_OF_ENTITIES )
		return NULLENT;

	static pSprite; pSprite = fm_find_ent_by_owner( NULLENT, aData[ eMuzzle_ClassName ], pPlayer );

	// If finded invalid entity or valid, but another iMuzzleId, try create new
	if ( is_nullent( pSprite ) || !is_nullent( pSprite ) && get_entvar( pSprite, var_impulse ) != iMuzzleId )
	{
		if ( ( pSprite = rg_create_entity( EntityMuzzleFlashReference ) ) && is_nullent( pSprite ) )
			return NULLENT;
	}

	// If finded valid entity and iMuzzleId is correct, reset frame to 0.0
	else if ( get_entvar( pSprite, var_impulse ) == iMuzzleId )
	{
		set_entvar( pSprite, var_frame, 0.0 );
		return pSprite;
	}

#if defined _reapi_included
	set_entvar( pSprite, var_classname, aData[ eMuzzle_ClassName ] );
#else
	set_entvar_string( pSprite, var_classname, gl_iszAllocString_Muzzleflash );
#endif
	set_entvar( pSprite, var_sprite_flags, aData[ eMuzzle_Flags ] );
	set_entvar( pSprite, var_impulse, iMuzzleId );

	set_entvar( pSprite, var_rendermode, kRenderTransAdd );
	set_entvar( pSprite, var_rendercolor, aData[ eMuzzle_Color ] );
	set_entvar( pSprite, var_renderamt, aData[ eMuzzle_Alpha ] );

	set_entvar( pSprite, var_scale, aData[ eMuzzle_Scale ] );
	set_entvar( pSprite, var_owner, pPlayer );
	set_entvar( pSprite, var_aiment, pPlayer );
	set_entvar( pSprite, var_body, aData[ eMuzzle_Attachment ] );
	
	engfunc( EngFunc_SetModel, pSprite, aData[ eMuzzle_Sprite ] );
	dllfunc( DLLFunc_Spawn, pSprite );

	set_entvar( pSprite, var_frame, 0.0 );

	if ( aData[ eMuzzle_Flags ] != MuzzleFlashFlag_Static )
	{
		static Float: flGameTime; flGameTime = get_gametime( );
		
		set_entvar( pSprite, var_framerate, aData[ eMuzzle_MaxFrames ] / aData[ eMuzzle_FrameRateMlt ] );
		set_entvar( pSprite, var_max_frame, aData[ eMuzzle_MaxFrames ] - 1.0 );

		set_entvar( pSprite, var_update_frame, aData[ eMuzzle_UpdateTime ] );
		set_entvar( pSprite, var_last_time, flGameTime );
		set_entvar( pSprite, var_nextthink, flGameTime );

	#if defined _reapi_included
		SetThink( pSprite, "CMuzzleFlash__Think" );
	#endif
	}

#if defined _reapi_included && defined ShowSpriteOnlyForOwner
	set_entvar( pSprite, var_effects, get_entvar( pSprite, var_effects ) | EF_OWNER_VISIBILITY );
#endif

	return pSprite;
}

public CMuzzleFlash__Think( const pSprite )
{
#if !defined _reapi_included
	if ( is_nullent( pSprite ) || get_entvar( pSprite, var_classname ) != gl_iszAllocString_Muzzleflash )
		return;
#endif

	if ( !IsMuzzleValid( get_entvar( pSprite, var_impulse ) ) )
		return;

	static iSpawnFlags; iSpawnFlags = get_entvar( pSprite, var_sprite_flags );
	static Float: flGameTime; flGameTime = get_gametime( );
	static Float: flFrame; get_entvar( pSprite, var_frame, flFrame );
	static Float: flMaxFrame; get_entvar( pSprite, var_max_frame, flMaxFrame );
	static Float: flFrameRate; get_entvar( pSprite, var_framerate, flFrameRate );
	static Float: flLastTime; get_entvar( pSprite, var_last_time, flLastTime );
	static Float: flUpdateFrame; get_entvar( pSprite, var_update_frame, flUpdateFrame );

	flFrame += ( flFrameRate * ( flGameTime - flLastTime ) );
	if ( flFrame > flMaxFrame )
	{
		if ( iSpawnFlags == MuzzleFlashFlag_Once )
		{
			UTIL_KillEntity( pSprite );
			return;
		}
		else flFrame = 0.0;
	}

	set_entvar( pSprite, var_frame, flFrame );
	set_entvar( pSprite, var_last_time, flGameTime );
	set_entvar( pSprite, var_nextthink, flGameTime + flUpdateFrame );
}

public bool: CMuzzleFlash__Destroy( const pPlayer, const MuzzleFlash: iMuzzleId )
{
	if ( !IsMuzzleValid( iMuzzleId, true ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Destroy", "MuzzleFlash with index (%i) not found.", iMuzzleId );
		return false;
	}

	static pEntity; pEntity = NULLENT;
	if ( pPlayer == 0 )
	{
		while ( ( pEntity = fm_find_ent_by_class( pEntity, EntityMuzzleFlashClassname ) ) > 0 )
		{
			if ( iMuzzleId > Invalid_MuzzleFlash && MuzzleFlash: get_entvar( pEntity, var_impulse ) != iMuzzleId )
				continue;

			UTIL_KillEntity( pEntity );
			if ( iMuzzleId > Invalid_MuzzleFlash ) break;
		}

		return true;
	}
	else if ( is_user_connected( pPlayer ) )
	{
		// With 'rg_find_ent_by_owner' server can went into an endless loop
		while ( ( pEntity = fm_find_ent_by_owner( pEntity, EntityMuzzleFlashClassname, pPlayer ) ) > 0 )
		{
			if ( iMuzzleId > Invalid_MuzzleFlash && MuzzleFlash: get_entvar( pEntity, var_impulse ) != iMuzzleId )
				continue;

			UTIL_KillEntity( pEntity );
			if ( iMuzzleId > Invalid_MuzzleFlash ) break;
		}

		return true;
	}
	else
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Destroy", "Invalid Player (%i)", pPlayer );
		return false;
	}

#if AMXX_VERSION_NUM <= 183
	return false;
#endif
}

PrepareErrorLog( const szAction[ ], const szError[ ], any:... )
{
	static szBuffer[ 256 ];
	vformat( szBuffer, charsmax( szBuffer ), szError, 3 );
	format( szBuffer, charsmax( szBuffer ), "%s %s (%s)", PluginPrefix, szBuffer, szAction );

#if defined UseSafeErrorLogs
	log_amx( szBuffer );
#else
	log_error( AMX_ERR_NATIVE, szBuffer );
#endif

	return true;
}

/* ~ [ Natives ] ~ */
public native_muzzle_init( const iPlugin, const iParams )
{
	new any: aData[ eMuzzleFlashData ];
	aData[ eMuzzle_ClassName ] = EntityMuzzleFlashClassname;
	aData[ eMuzzle_Sprite ] = EOS;
	aData[ eMuzzle_Attachment ] = 1;
	aData[ eMuzzle_Scale ] = 0.05;
	aData[ eMuzzle_UpdateTime ] = 0.035;
	aData[ eMuzzle_FrameRateMlt ] = 1.0;
	aData[ eMuzzle_Color ] = Float: { 0.0, 0.0, 0.0 };
	aData[ eMuzzle_Alpha ] = 255.0;
	aData[ eMuzzle_MaxFrames ] = 1.0;
	aData[ eMuzzle_Flags ] = MuzzleFlashFlag_Once;

	ArrayPushArray( gl_arMuzzleFlashData, aData );

	return ++gl_iMuzzlesCount - 1;
}

public bool: native_muzzle_clear( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Clear", "MuzzleFlash Array is Invalid." );
		return false;
	}

	enum { arg_muzzle_id = 1 };

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( MuzzleFlash: iMuzzleId == Invalid_MuzzleFlash )
	{
		ArrayClear( gl_arMuzzleFlashData );
		gl_iMuzzlesCount = 0;
	}
	else
	{
		ArrayDeleteItem( gl_arMuzzleFlashData, iMuzzleId ); 
		gl_iMuzzlesCount--;
	}

	return true;
}

public any: native_muzzle_get_property( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Get Property", "MuzzleFlash Array is Invalid." );
		return false;
	}

	enum { arg_muzzle_id = 1, arg_property, arg_value, arg_len };

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( !IsMuzzleValid( iMuzzleId ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Get Property", "MuzzleFlash with index (%i) not found.", iMuzzleId );
		return false;
	}

	new iProperty = get_param( arg_property );
	new aData[ eMuzzleFlashData ]; ArrayGetArray( gl_arMuzzleFlashData, iMuzzleId, aData );

	switch ( eMuzzleProperties: iProperty )
	{
		case ZC_MUZZLE_CLASSNAME: set_string( arg_value, aData[ eMuzzle_ClassName ], get_param_byref( arg_len ) );
		case ZC_MUZZLE_SPRITE: set_string( arg_value, aData[ eMuzzle_Sprite ], get_param_byref( arg_len ) );
		case ZC_MUZZLE_ATTACHMENT: return aData[ eMuzzle_Attachment ];
		case ZC_MUZZLE_SCALE: return aData[ eMuzzle_Scale ];
		case ZC_MUZZLE_UPDATE_TIME: return aData[ eMuzzle_UpdateTime ];
		case ZC_MUZZLE_FRAMERATE_MLT: return aData[ eMuzzle_FrameRateMlt ];
		case ZC_MUZZLE_COLOR: set_array_f( arg_value, aData[ eMuzzle_Color ], 3 );
		case ZC_MUZZLE_ALPHA: return aData[ eMuzzle_Alpha ];
		case ZC_MUZZLE_MAX_FRAMES: return aData[ eMuzzle_MaxFrames ];
		case ZC_MUZZLE_FLAGS: return aData[ eMuzzle_Flags ];
		default:
		{
			WriteErrorLogs && PrepareErrorLog( "Muzzle Get Property", "Property (%i) not found for MuzzleFlash (Id: %i)", iProperty, iMuzzleId );
			return false;
		}
	}

	return true;
}

public native_muzzle_set_property( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Set Property", "MuzzleFlash Array is Invalid." );
		return false;
	}

	enum { arg_muzzle_id = 1, arg_property, arg_value };

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( !IsMuzzleValid( iMuzzleId ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Set Property", "MuzzleFlash with index (%i) not found.", iMuzzleId );
		return false;
	}

	new iProperty = get_param( arg_property );
	new any: aData[ eMuzzleFlashData ]; ArrayGetArray( gl_arMuzzleFlashData, iMuzzleId, aData );

	switch ( eMuzzleProperties: iProperty )
	{
		case ZC_MUZZLE_SPRITE:
		{
			get_string( arg_value, aData[ eMuzzle_Sprite ], charsmax( aData[ eMuzzle_Sprite ] ) );
		
			if ( !IsNullString( aData[ eMuzzle_Sprite ] ) )
			{
				static iModelIndex; iModelIndex = engfunc( EngFunc_PrecacheModel, aData[ eMuzzle_Sprite ] );
				aData[ eMuzzle_MaxFrames ] = float( engfunc( EngFunc_ModelFrames, iModelIndex ) );
			}
		}
		case ZC_MUZZLE_ATTACHMENT: aData[ eMuzzle_Attachment ] = get_param_byref( arg_value );
		case ZC_MUZZLE_SCALE: aData[ eMuzzle_Scale ] = get_float_byref( arg_value );
		case ZC_MUZZLE_UPDATE_TIME: aData[ eMuzzle_UpdateTime ] = get_float_byref( arg_value );
		case ZC_MUZZLE_FRAMERATE_MLT: aData[ eMuzzle_FrameRateMlt ] = get_float_byref( arg_value );
		case ZC_MUZZLE_COLOR: get_array_f( arg_value, aData[ eMuzzle_Color ], 3 );
		case ZC_MUZZLE_ALPHA: aData[ eMuzzle_Alpha ] = get_float_byref( arg_value );
		case ZC_MUZZLE_MAX_FRAMES: aData[ eMuzzle_MaxFrames ] = get_float_byref( arg_value );
		case ZC_MUZZLE_FLAGS: aData[ eMuzzle_Flags ] = get_param_byref( arg_value );
		default:
		{
			WriteErrorLogs && PrepareErrorLog( "Muzzle Set Property", "Property (%i) not found for MuzzleFlash (Id: %i)", iProperty, iMuzzleId );
			return false;
		}
	}

	ArraySetArray( gl_arMuzzleFlashData, iMuzzleId, aData );

	return true;
}

public native_muzzle_find( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Find", "MuzzleFlash Array is Invalid." );
		return -1;
	}

	enum { arg_player = 1, arg_muzzle_id };

	new pPlayer = get_param( arg_player );
	if ( !is_user_connected( pPlayer ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Find", "Invalid Player (%i)", pPlayer );
		return -1;
	}

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( !IsMuzzleValid( iMuzzleId, true ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Find", "MuzzleFlash with index (%i) not found.", iMuzzleId );
		return -1;
	}

	new pEntity = NULLENT;
	while ( ( pEntity = fm_find_ent_by_owner( pEntity, EntityMuzzleFlashClassname, pPlayer ) ) > 0 )
	{
		if ( MuzzleFlash: iMuzzleId > Invalid_MuzzleFlash && get_entvar( pEntity, var_impulse ) != iMuzzleId )
			continue;

		break;
	}

	return is_nullent( pEntity ) ? NULLENT : pEntity;
}

public native_muzzle_draw( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Draw", "MuzzleFlash Array is Invalid." );
		return -1;
	}

	enum { arg_player = 1, arg_muzzle_id };

	new pPlayer = get_param( arg_player );
	if ( !is_user_connected( pPlayer ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Draw", "Invalid Player (%i)", PluginPrefix, pPlayer );
		return -1;
	}

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( !IsMuzzleValid( iMuzzleId ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Draw", "MuzzleFlash with index (%i) not found.", iMuzzleId );
		return -1;
	}

	new aData[ eMuzzleFlashData ]; ArrayGetArray( gl_arMuzzleFlashData, iMuzzleId, aData );
	if ( IsNullString( aData[ eMuzzle_ClassName ] ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Draw", "Can't create a MuzzleFlash with empty classname." );
		return -1;
	}

	if ( IsNullString( aData[ eMuzzle_Sprite ] ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Draw", "MuzzleFlash with index (%i) not found.", iMuzzleId );
		return -1;
	}

	return CMuzzleFlash__SpawnEntity( pPlayer, iMuzzleId, aData );
}

public bool: native_muzzle_destroy( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		WriteErrorLogs && PrepareErrorLog( "Muzzle Destroy", "MuzzleFlash Array is Invalid." );
		return false;
	}

	enum { arg_player = 1, arg_muzzle_id };

	return CMuzzleFlash__Destroy( get_param( arg_player ), MuzzleFlash: get_param( arg_muzzle_id ) );
}

/* ~ [ Stocks ] ~ */

/* -> Check MuzzleFlash is Valid <- */
stock bool: IsMuzzleValid( const any: iMuzzleId, const bool: bAllowInvalid = false )
{
	if ( bAllowInvalid )
		return ( Invalid_MuzzleFlash <= iMuzzleId < gl_iMuzzlesCount );

	return ( Invalid_MuzzleFlash < iMuzzleId < gl_iMuzzlesCount );
}

/* -> Destroy Entity <- */
stock UTIL_KillEntity( const pEntity ) 
{
	set_entvar( pEntity, var_flags, FL_KILLME );
	set_entvar( pEntity, var_nextthink, get_gametime( ) );
}
