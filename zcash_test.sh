### these are for AWS FPGA config ###
cd $AWS_FPGA_REPO_DIR && source sdk_setup.sh
echo "always be sure to source the sdk_setup.sh"
echo " "
echo "clear the fpga AFI..."
sudo fpga-clear-local-image -S -0
echo " "
echo "reload the fpga AFI..."
sleep 3
sudo fpga-load-local-image -S 0 -I agfi-0ef71fd274fd5b46e
echo "If FPGA image load correctlly, it is ready for the test"

cd ~/aws-fpga/hdk/cl/developer_designs/cl_zcash/software/runtime
echo "Ready for run Zcash FPGA test!"

sleep 2
echo " "
sleep 2
echo " "
sudo ./test_zcash
