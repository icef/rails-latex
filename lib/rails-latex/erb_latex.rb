# -*- coding: utf-8 -*-
require 'fileutils'
require 'rails-latex/latex_to_pdf'
require 'rails-latex/latex_output_buffer'
require 'action_view'

module ActionView               # :nodoc: all
  module Template::Handlers
    class ErubisLatex < Erubis
      def add_preamble(src)
        src << "@output_buffer = output_buffer || RailsLatex::LatexOutputBuffer.new;"
      end
    end

    class ERBLatex < ERB
      self.erb_implementation = ErubisLatex
    end
  end

  Template.register_template_handler :erbtex, Template::Handlers::ERBLatex
end

