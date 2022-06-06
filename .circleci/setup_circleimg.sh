#!/usr/bin/env bash
#
# Copyright (c) 2016-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#

if [ $(lsb_release -cs) == "stretch" ]; then
  sudo apt-get --allow-releaseinfo-change-suite update
else
  sudo apt-get update
fi
sudo apt-get install -y cmake python-pip python-dev build-essential
