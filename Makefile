export MIX_TARGET := rpi4
export MIX_ENV := prod
export DESTINATION := barbecue.local

.PHONY: deps firmware burn

deps:
	mix deps.get

assets: deps
	mix assets.deploy

firmware: deps assets
	mix firmware

burn: firmware
	mix firmware.burn -d /dev/rdisk8

upload: firmware
	mix upload barbecue.local