module Rome
  class Graph
    
    SECONDS = 1
    MINUTES = 60 * SECONDS
    HOURS = 60 * MINUTES
    DAYS = 24 * HOURS
    
    class << self
      def for_milestone(milestone, options = {})
        
        duration_in_days = (milestone.duration / DAYS).round
        x_axis = (0...(duration_in_days-1)).to_a.collect { |i| milestone.start_on + i.days }
        
        # we substract 1 because we're starting from 0
        real_data = x_axis.collect do |target_day|
          
          # midnight is actually morning, so add another day
          if (Time.now.midnight + 1.day) > target_day
            milestone.time_remaining_on_day(target_day, options)
          else
          # returning -1 results is "no data" for the GoogleChart::LineChart
            -1
          end
        end
        
        
        projected_data = [milestone.time_total(options),0]
        adjusted_projected_data = [real_data.max,0]
        
        y_axis = (0..(adjusted_projected_data.max / HOURS)).to_a
        
        graph = returning GoogleChart::LineChart.new do |lc|
          lc.data("Real progress", real_data, "0000FF")
          lc.data("Original Projection", projected_data, "00FF00")
          lc.data("Adjusted projection", adjusted_projected_data, "FF0000")
          lc.axis :x, :range => (0...x_axis.size).to_a
          lc.axis :y, :range => y_axis
        end
        
        x_grid = (100.0 / (x_axis.size - 1))
        y_grid = (100.0 / y_axis.max) * 10.0
        
        graph_options = {}
        graph_options[:chs] = "700x400"
        graph_options[:chtt] = milestone.title
        graph_options[:chg] = "#{x_grid},#{y_grid}"
        graph_options[:chxl] = "0:|#{x_axis.collect { |d| d.strftime("%d-%m") }.join("|")}|"
        graph.to_url(graph_options.merge(options[:to_url] || {}))
      end

      def summary_for_milestone(milestone, options={})
        milestone.members.sort_by { |m| m.name }.collect do |member|
          
          members_tickets = milestone.tickets_with_estimates(:assigned_user_id => member.id).select(&:open?)
          estimates = members_tickets.collect { |t| t.estimates.last.to_i }
          
          time_remaining = estimates.empty? ? 0 : estimates.inject(&:+) / HOURS
          
          [member.name, members_tickets, time_remaining, for_milestone(milestone, :assigned_user_id => member.id)]
        end 
      end
      
      def print_summary_for_milestone(milestone, options={})
        summary_for_milestone(milestone, options).each do |name, tickets, time_remaining, graph|
          puts "h1. #{name.upcase}"
          puts ""
          puts "#{time_remaining} hours remaining:"
          puts ""
          tickets.sort_by { |t| t.estimates.last.to_i }.reverse.each do |ticket|
            puts "  * #{ticket.id} -- #{ticket.title}, #{ticket.estimates.last.to_i / HOURS} hours left"
          end
          puts ""
          puts "!#{graph}!"
          puts "\n\n"
        end
        ""
      end
    end
  end
end