# -*- mode: ruby -*-
# -*- encoding: utf-8 -*-
Pkgr.build do
  target do
    platform 'ubuntu' # keep inline with chef platform values
    package 'deb' # rpm, etc
    arch 'x86_64' # do we care about 32bit?
  end
  source do
    type :git # remote (we can probably infer)
    location 'git://blahblah.com/project.git'
    reference 'some-tag'
  end
  dependencies do
    build do
      package1
      package2
      package3 '0.3.0'
    end
    runtime [package1, package2, package3]

    ###### so we are going to want to run down to leaves within the
    ###### worker itself. once the leaf points are reached, we can
    ###### start a process for each leaf. then walk back up to the
    ###### root and queue jobs along the way back up. should be able
    ###### to make this an implicit triggering system
    package.runit do
      source do
        type :internal # :external
        git 'git://github.com/runit/runit.git'
      end
      dependencies do
      end
      build do
      end
    end
  end
  build do
    name 'my-cool-app'
    version '#we should generate this'
    template :rails
    commands do
      before.dependencies [
        'comms',
        -> {
          environment do
            fubar 'V2'
            feebar 'V3'
          end
          command '/bin/do-stuff'
        },
        'moar-things'
      ]
      after.dependencies ['comms']
      before.build ['comms']
      after.build ['comms']
      build ['comms'] # not valid with template set
    end
    configure do
      prefix '/usr/local'
    end
  end
end
