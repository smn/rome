module Rome
  module PaginationHelper
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def find_all_across_pages(options = {})
        records = []
        each(options) { |record| records << record }
        records
      end

      def each(options = {})
        options[:params] ||= {}
        options[:params][:page] = 1

        loop do
          if (records = self.find(:all, options)).any?
            records.each { |record| yield record }
            options[:params][:page] += 1
          else
            break # no people included on that page, thus no more people total
          end
        end
      end
    end
  end
end