# Relocatable copy of the measured wrapper. Linux adaptation is not yet executed.
# Supply absolute paths; use a private Replicant checkout and fresh TASK_ROOT.
ifndef TASK_ROOT
$(error Set TASK_ROOT to an isolated experiment output directory)
endif
ifndef MERGED_ROOT
$(error Set MERGED_ROOT to the pinned bsg_bladerunner source tree)
endif
ifndef EXPERIMENT_VERILATOR_ROOT
$(error Set EXPERIMENT_VERILATOR_ROOT to this configured Verilator checkout)
endif
CL_DIR := $(TASK_ROOT)/bsg_replicant
BSG_F1_DIR := $(CL_DIR)
BASEJUMP_STL_DIR := $(MERGED_ROOT)/basejump_stl
BSG_MANYCORE_DIR := $(MERGED_ROOT)/bsg_manycore
override VERILATOR_ROOT := $(EXPERIMENT_VERILATOR_ROOT)
override VERILATOR := $(VERILATOR_ROOT)/bin/verilator
export VERILATOR_ROOT
BSG_MACHINE_PATH := $(CL_DIR)/machines/pod_X1Y1_ruche_X16Y8_hbm_one_pseudo_channel
MODEL_VARIANT ?= one
override BSG_MACHINExPLATFORM_PATH := $(TASK_ROOT)/models/$(MODEL_VARIANT)
IGNORE_CADENV := 1
BSG_PLATFORM := bigblade-verilator
DEFINES :=
include $(CL_DIR)/environment.mk
include $(EXAMPLES_PATH)/compilation.mk
include $(EXAMPLES_PATH)/link.mk
VERILATOR_VFLAGS += $(EXPERIMENT_VFLAGS)
