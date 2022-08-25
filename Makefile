.PHONY: init
init:
	git submodule update --init --recursive
	brew bundle
	rbenv install --skip-existing
	rbenv exec gem update bundler
	rbenv exec bundle update
	rbenv exec bundle exec pod update
