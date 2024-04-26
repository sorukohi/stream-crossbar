SCRIPTS_PATH = ./scripts
TMP_PATH = ./tmp

TEST = crossbar_3x4

synth:
	vivado -mode tcl -nolog -nojournal -source $(SCRIPTS_PATH)/synth.tcl 

sim:
	vivado -mode tcl -nolog -nojournal -source $(SCRIPTS_PATH)/sim.tcl -tclargs $(TEST)
	# tclsh $(SCRIPTS_PATH)/sim.tcl $(TEST)
	
clean:
ifeq ($(OS), Windows_NT)
	rmdir /Q /S $(TMP_PATH)
	rmdir /Q /S .Xil
else
	rm -fr $(TMP_PATH)
	rm -fr /Q /S .Xil
endif