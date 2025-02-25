fx_version 'cerulean'
game 'gta5'

name "ps-buffs"
description "Buff tracker for qbcore"
author "Idris"
version "0.0.1"

lua54 'yes'
use_fxv2_oal 'yes'

shared_scripts {
	'@es_extended/imports.lua',
    '@ox_lib/init.lua',
	'shared/config.lua',
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'server/*.lua'
}

dependencies {
	'es_extended'
}
