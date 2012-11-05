require 'rails-latex/latex_to_pdf'
require 'action_view'

module RailsLatex
  class LatexOutputBuffer < ActionView::OutputBuffer

    def concat(value)
      if !html_safe? || value.html_safe?
        super(value)
      else
        super(LatexToPdf.escape_latex(value))
      end
    end

    def <<(value)
      concat(value.to_s)
    end

    alias :append= :<<
  end
end
