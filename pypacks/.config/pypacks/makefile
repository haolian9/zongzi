.PHONY:

install: requirements.txt
	@ python3 -m pip install --user --upgrade -r requirements.txt

freeze_as_requirements:
	@ poetry export --format requirements.txt --without-hashes > requirements.txt

uninstall:
	python3 -m pip uninstall --yes -r requirements.txt
