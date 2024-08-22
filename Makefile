initialize:
	git submodule update --init
	cd dep/tap-utils/ ; git submodule update --init lib/permitc