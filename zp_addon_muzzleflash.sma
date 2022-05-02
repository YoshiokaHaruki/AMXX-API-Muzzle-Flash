public stock const PluginName[ ] =			"[API] Addon: MuzzleFlash";
public stock const PluginVersion[ ] =		"1.0";
public stock const PluginAuthor[ ] =		"Yoshioka Haruki";
public stock const PluginPrefix[ ] =		"API:MuzzleFlash";

/* ~ [ Includes ]~ */
#include <amxmodx>
#include <fakemeta_util>
#include <reapi>
#include <api_muzzleflash>

/* ~ [ Plugin Settings ] ~ */
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
	MuzzleFlashFlags: eMuzzle_Flags
};
new Array: gl_arMuzzleFlashData;

/* ~ [ Macroses ] ~ */
#define LOWER_LIMIT_OF_ENTITIES				100

#define IsNullString(%0)					bool: ( %0[ 0 ] == EOS )
#define IsArrayInvalid(%0)					( %0 == Invalid_Array || !ArraySize( %0 ) )

#define var_max_frame						var_yaw_speed // CEntity: env_sprite
#define var_last_time						var_pitch_speed // CEntity: env_sprite
#define var_update_frame					var_ideal_yaw // CEntity: env_sprite

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
	register_plugin( PluginName, PluginVersion, PluginAuthor );

	/* -> Array's -> */
	gl_arMuzzleFlashData = ArrayCreate( eMuzzleFlashData );
}

/* ~ [ Other ] ~ */
public CMuzzleFlash__SpawnEntity( const pPlayer, const iMuzzleId, const aData[ ] )
{
	static iMaxEntities; if ( !iMaxEntities ) iMaxEntities = global_get( glb_maxEntities );
	if ( iMaxEntities - engfunc( EngFunc_NumberOfEntities ) <= LOWER_LIMIT_OF_ENTITIES )
		return NULLENT;

	new pSprite = fm_find_ent_by_owner( NULLENT, aData[ eMuzzle_ClassName ], pPlayer );

	// If finded invalid entity or valid, but another iMuzzleId, try create new
	if ( is_nullent( pSprite ) || !is_nullent( pSprite ) && get_entvar( pSprite, var_impulse ) != iMuzzleId )
	{
		static szEntityReference[ 16 ];
		if ( !IsNullString( szEntityReference ) )
			szEntityReference = "env_sprite";

		if ( ( pSprite = rg_create_entity( szEntityReference ) ) && is_nullent( pSprite ) )
			return NULLENT;
	}

	// If finded valid entity and iMuzzleId is correct, reset frame to 0.0
	else if ( get_entvar( pSprite, var_impulse ) == iMuzzleId )
	{
		set_entvar( pSprite, var_frame, 0.0 );
		return pSprite;
	}

	set_entvar( pSprite, var_classname, aData[ eMuzzle_ClassName ] );
	set_entvar( pSprite, var_spawnflags, aData[ eMuzzle_Flags ] );
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

		SetThink( pSprite, "CMuzzleFlash__Think" );
	}

	return pSprite;
}

public CMuzzleFlash__Think( const pSprite )
{
	if ( is_nullent( pSprite ) )
		return;

	static Float: flFrame; flFrame = get_entvar( pSprite, var_frame );
	static Float: flGameTime; flGameTime = get_gametime( );

	flFrame += ( Float: get_entvar( pSprite, var_framerate ) * ( flGameTime - Float: get_entvar( pSprite, var_last_time ) ) );
	if ( flFrame > Float: get_entvar( pSprite, var_max_frame ) )
	{
		if ( get_entvar( pSprite, var_spawnflags ) == MuzzleFlashFlag_Once )
		{
			UTIL_KillEntity( pSprite );
			return;
		}
		else flFrame = 0.0;
	}

	set_entvar( pSprite, var_frame, flFrame );
	set_entvar( pSprite, var_last_time, flGameTime );
	set_entvar( pSprite, var_nextthink, flGameTime + Float: get_entvar( pSprite, var_update_frame ) );
}

public bool: CMuzzleFlash__Destroy( const pPlayer, const MuzzleFlash: iMuzzleId )
{
	if ( iMuzzleId < Invalid_MuzzleFlash || iMuzzleId >= MuzzleFlash: ArraySize( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash with index (%i) not found.", PluginPrefix, iMuzzleId );
		return false;
	}

	new pEntity = NULLENT;
	if ( pPlayer == 0 )
	{
		while ( ( pEntity = fm_find_ent_by_class( pEntity, EntityMuzzleFlashClassname ) ) > 0 )
		{
			if ( iMuzzleId > Invalid_MuzzleFlash && get_entvar( pEntity, var_impulse ) != iMuzzleId )
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
			if ( iMuzzleId > Invalid_MuzzleFlash && get_entvar( pEntity, var_impulse ) != iMuzzleId )
				continue;

			UTIL_KillEntity( pEntity );
			if ( iMuzzleId > Invalid_MuzzleFlash ) break;
		}

		return true;
	}
	else
	{
		log_amx( "%s Invalid Player (%i)", PluginPrefix, pPlayer );
		return false;
	}
}

/* ~ [ Natives ] ~ */
public native_muzzle_init( const iPlugin, const iParams )
{
	new aData[ eMuzzleFlashData ];
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

	return ArraySize( gl_arMuzzleFlashData ) - 1;
}

public bool: native_muzzle_clear( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash is Invalid.", PluginPrefix );
		return false;
	}

	enum { arg_muzzle_id = 1 };

	new iMuzzleId = get_param( arg_muzzle_id );
	( MuzzleFlash: iMuzzleId == Invalid_MuzzleFlash ) ? ArrayClear( gl_arMuzzleFlashData ) : ArrayDeleteItem( gl_arMuzzleFlashData, iMuzzleId ); 

	return true;
}

public any: native_muzzle_get_property( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash is Invalid.", PluginPrefix );
		return false;
	}

	enum { arg_muzzle_id = 1, arg_property, arg_value, arg_len };

	new iMuzzleId = get_param( arg_muzzle_id );
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
			log_amx( "%s Property (%i) not found for MuzzleFlash (Id: %i)", PluginPrefix, iProperty, iMuzzleId );
			return false;
		}
	}

	return true;
}

public native_muzzle_set_property( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash is Invalid.", PluginPrefix );
		return false;
	}

	enum { arg_muzzle_id = 1, arg_property, arg_value };

	new iMuzzleId = get_param( arg_muzzle_id );
	new iProperty = get_param( arg_property );
	new aData[ eMuzzleFlashData ]; ArrayGetArray( gl_arMuzzleFlashData, iMuzzleId, aData );

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
		case ZC_MUZZLE_FLAGS: aData[ eMuzzle_Flags ] = MuzzleFlashFlags: get_float_byref( arg_value );
		default:
		{
			log_amx( "%s Property (%i) not found for MuzzleFlash (Id: %i)", PluginPrefix, iProperty, iMuzzleId );
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
		log_amx( "%s MuzzleFlash is Invalid.", PluginPrefix );
		return -1;
	}

	enum { arg_player = 1, arg_muzzle_id };

	new pPlayer = get_param( arg_player );
	if ( !is_user_connected( pPlayer ) )
	{
		log_amx( "%s Invalid Player (%i)", PluginPrefix, pPlayer );
		return -1;
	}

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( MuzzleFlash: iMuzzleId < Invalid_MuzzleFlash || iMuzzleId >= ArraySize( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash with index (%i) not found.", PluginPrefix, iMuzzleId );
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
		log_amx( "%s MuzzleFlash is Invalid.", PluginPrefix );
		return -1;
	}

	enum { arg_player = 1, arg_muzzle_id };

	new pPlayer = get_param( arg_player );
	if ( !is_user_connected( pPlayer ) )
	{
		log_amx( "%s Invalid Player (%i)", PluginPrefix, pPlayer );
		return -1;
	}

	new iMuzzleId = get_param( arg_muzzle_id );
	if ( MuzzleFlash: iMuzzleId <= Invalid_MuzzleFlash || iMuzzleId >= ArraySize( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash with index (%i) not found.", PluginPrefix, iMuzzleId );
		return -1;
	}

	new aData[ eMuzzleFlashData ]; ArrayGetArray( gl_arMuzzleFlashData, iMuzzleId, aData );
	if ( IsNullString( aData[ eMuzzle_ClassName ] ) )
	{
		log_amx( "%s Can't create a MuzzleFlash with empty classname.", PluginPrefix );
		return -1;
	}

	if ( IsNullString( aData[ eMuzzle_Sprite ] ) )
	{
		log_amx( "%s MuzzleFlash with index (%i) not found.", PluginPrefix, iMuzzleId );
		return -1;
	}

	return CMuzzleFlash__SpawnEntity( pPlayer, iMuzzleId, aData );
}

public bool: native_muzzle_destroy( const iPlugin, const iParams )
{
	if ( IsArrayInvalid( gl_arMuzzleFlashData ) )
	{
		log_amx( "%s MuzzleFlash is Invalid.", PluginPrefix );
		return false;
	}

	enum { arg_player = 1, arg_muzzle_id };

	return CMuzzleFlash__Destroy( get_param( arg_player ), MuzzleFlash: get_param( arg_muzzle_id ) );
}

/* ~ [ Stocks ] ~ */

/* -> Destroy Entity <- */
stock UTIL_KillEntity( const pEntity ) 
{
	set_entvar( pEntity, var_flags, FL_KILLME );
	set_entvar( pEntity, var_nextthink, get_gametime( ) );
}
