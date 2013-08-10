default: all

MOCHA  = node_modules/.bin/mocha --recursive --compilers ls:LiveScript -u tdd
LSC    = node_modules/.bin/lsc

build:
	${LSC} --output lib --bare --compile src

watch:
	${LSC} --output lib --bare --compile --watch src

.PHONY : test test-unit test-integration
test: test-unit test-integration
test-unit: build
	NODE_ENV=test ${MOCHA} -R spec --recursive test/unit
test-integration: build
	NODE_ENV=test ${MOCHA} -R spec --recursive test/integration

.PHONY: release

release:
	git push --tags origin HEAD:master
	npm publish
