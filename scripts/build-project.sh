#!/bin/bash

# Parsing absolute filepath of this script
abs_filepath=$(readlink -f $0)
abs_dirpath=$(dirname $abs_filepath)
build_dirpath=$(dirname $abs_dirpath)
echo $build_dirpath
# Build Lib
# apt update -y
# apt install -y tesseract-ocr ffmpeg libsm6 libxext6

# Install package-python in editable mode (developer) -> Exec from source code
pip install -r requirements.txt
python3 -m pip install --editable $build_dirpath --log $build_dirpath/build-log.txt

# Install package and copied to Python Environment (non-editable) -> Exec from python environment (not editable)
# python3 -m pip install $build_dirpath --log /opt/itc/src/build-log.txt

# Build distribution
# python3 -m build --sdist $build_dirpath
# python3 $build_dirpath/setup.py bdist_egg