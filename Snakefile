# dmc-mockserver

try:
	if not gSTARTED: print( gSTARTED )
except:
	MODULE = "dmc-mockserver"
	include: "../DMC-Corona-Library/snakemake/Snakefile"

module_config = {
	"name": "dmc-mockserver",
	"module": {
		"dir": "dmc_corona",
		"files": [
			"dmc_mockserver.lua"
		],
		"requires": [
			"dmc-corona-boot",
			"DMC-Lua-Library",
			"dmc-objects"
		]
	},
	"examples": {
		"base_dir": "examples",
		"apps": [
			{
				"exp_dir": "dmc-mockserver-simple",
				"requires": []
			}
		]
	},
	"tests": {
		"files": [],
		"requires": []
	}
}

register( "dmc-mockserver", module_config )
