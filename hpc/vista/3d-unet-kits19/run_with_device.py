import os
import runpy
import sys

sys.path.insert(0, os.getcwd())

import pytorch_SUT

_reference_get_sut = pytorch_SUT.get_sut


def get_sut_reporting_device(model_path, preprocessed_data_dir, performance_count):
    sut = _reference_get_sut(model_path, preprocessed_data_dir, performance_count)
    print("pytorch device: {}".format(next(sut.model.parameters()).device), flush=True)
    return sut


pytorch_SUT.get_sut = get_sut_reporting_device
sys.argv = ["run.py"] + sys.argv[1:]
runpy.run_path(os.path.join(os.getcwd(), "run.py"), run_name="__main__")