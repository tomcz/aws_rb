Examples of ruby integration with AWS
=====================================

This project provides a pure ruby/chef implementation of the fabric/boto/puppet setup from https://github.com/tomcz/aws_py
in order to showcase similarites and differences between puppet and chef.

Usage
-----

    ./go clean                 # Remove any temporary products.
    ./go clobber               # Remove any generated file.
    ./go mco_ping              # Run mcollective ping on the broker
    ./go provision[node_name]  # Provision a named node with chef-solo
    ./go provision_broker      # Provision a broker node with chef-solo
    ./go start[node_name]      # Create a named node
    ./go stop[node_name]       # Terminate named node
    ./go stop_all              # Terminate all running nodes

Requirements
------------

- [RVM](https://rvm.io/)
- Invoke the `./go` script.

License
-------

These scripts are covered by the [MIT License](http://www.opensource.org/licenses/mit-license.php).
