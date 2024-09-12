module Pod
  module SPM
    class Dependency
      attr_reader :name, :product
      attr_accessor :pkg

      def initialize(name, options = {}, product: nil, pkg: nil)
        cmps = name.split("/")
        raise "Invalid dependency `#{name}`" if cmps.count > 2

        @name = cmps.first
        @product = product || cmps.last
        @options = options
        @pkg = pkg
      end

      def linkage
        # TODO: How to detect the linkage of an SPM library?
        @pkg.linkage.is_a?(Hash) ? @pkg.linkage[@product] : @pkg.linkage
      end

      def dynamic?
        linkage == :dynamic
      end

      def inspect
        "#<#{self.class} name=#{name} product=#{product} pkg=#{pkg}>"
      end

      def mp_test_pckg?
        [
          'EntwineTest', 
          'LocalizationTestExtensions', 
          'TestExtensions', 
          'SnapshotTestExtensions', 
          'SnapshotTesting', 
          'SnapshotTestingEx'
        ].include?(product)
      end
    end
  end
end
