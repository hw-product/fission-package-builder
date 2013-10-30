# Fission Package Builder

This is a worker.

## About

Package builder is a worker process in the Fission application that makes packages. This
service reads from a configuration file, see Usage examples. After consuming the configuration
builder will format a first run json chef configuration. Fission Package Builder then runs
chef-solo for the configuration payload on host node and then runs <link to cookbook> pkg-build
to determine which package(s) should be built. The pkg-build cookbook will then spawn an ephemeral
lxc container, one per package, which runs chef-solo with the first run configuration generated
previously. Pkg-build runs and builds package(s).

## Getting Started

Do magic!

## Usage examples

```
Packomatic.describe do
  target do
    platform 'ubuntu'
    package 'deb'
    arch 'x86_64'
  end
  dependencies do
    build [package1, package2, package3]
    runtime [package1, package2, package3]
    package.runit do
      source do
        type  :internal # :external
        git 'git://github.com/runit/runit.git'
      end
      dependencies do
      end
      build do
      end
  end
build do
  template :rails
  commands do
    before.dependencies ['comms']
    after.dependencies ['comms']
    before.build ['comms']
    after.build ['comms']
    build ['comms'] # not valid with template set
  end
  configure do
    prefix  '/usr/local'
  end
end
```
