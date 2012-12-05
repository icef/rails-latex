class LatexToPdf
  # Converts a string of LaTeX +code+ into a binary string of PDF.
  #
  # pdflatex is used to convert the file and creates the directory +#{Rails.root}/tmp/rails-latex/+ to store intermediate
  # files.
  #
  # The config argument defaults to LatexToPdf.config but can be overridden using @latex_config.
  def self.generate_pdf(tex_code, config)
    generator = PdfGenerator.new(tex_code, config)
    pdf_filename = generator.generate
    pdf_document = PdfDocument.new(pdf_filename: pdf_filename)
    generator.delete

    pdf_document
  end

  # Generates a binary pdf from the given rails template
  # The template has to be an tex template
  def self.generate_pdf_from_template(template_name, locals, options)
    av = ActionView::Base.new(Rails.configuration.paths["app/views"])
    av.class_eval do
      include ApplicationHelper
    end

    tex = av.render template: template_name, formats: [:tex], locals: locals
    self.generate_pdf(tex, options)
  end

  # Escapes LaTex special characters in text so that they wont be interpreted as LaTex commands.
  #
  # This method will use RedCloth to do the escaping if available.
  def self.escape_latex(text)
    # :stopdoc:
    unless @latex_escaper
      if defined?(RedCloth::Formatters::LATEX)
        class << (@latex_escaper=RedCloth.new(''))
          include RedCloth::Formatters::LATEX
        end
      else
        class << (@latex_escaper=Object.new)
          ESCAPE_RE=/([{}_$&%#])|([\\^~|<>])/
            ESC_MAP={
            '\\' => 'backslash',
            '^' => 'asciicircum',
            '~' => 'asciitilde',
            '|' => 'bar',
            '<' => 'less',
            '>' => 'greater',
          }

          def latex_esc(text)   # :nodoc:
            text.gsub(ESCAPE_RE) {|m|
              if $1
                "\\#{m}"
              else
                "\\text#{ESC_MAP[m]}{}"
              end
            }
          end
        end
      end
      # :startdoc:
    end

    @latex_escaper.latex_esc(text.to_s).html_safe
  end
end

class UnknownLatexBuildException < StandardError
end

class LatexBuildException < StandardError
  attr_accessor :log_file
end

class PdfDocument
  attr_reader :pdf_filename, :pdf_content, :page_count
  alias to_s pdf_content

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
  end

  def pdf_filename=(filename)
    @pdf_filename = filename
    @pdf_content  = File.read(filename)
    update_page_count!
    filename
  end

  private

  def update_page_count!
    reader = PDF::Reader.new(pdf_filename)
    @page_count = reader.page_count
  end
end

class PdfGenerator
  DEFAULT_CONFIG = { :command => 'pdflatex', :arguments => ['-halt-on-error'], :parse_twice => false }
  attr_accessor :tex_code, :config

  def initialize(tex_code, config = {})
    self.tex_code = tex_code
    self.config   = config
  end

  def generate
    configuration = DEFAULT_CONFIG.merge(config)
    create_directory  dir
    write_tex_to_file tex_code
    run_latex_command configuration
    handle_result
  end

  def delete
    FileUtils.rm_rf(dir)
  end

  private

  def handle_result
    if File.exist?(pdf_file)
      return pdf_file
    else
      exception = nil
      if File.exist?(log_file)
        exception = LatexBuildException.new("pdflatex failed: See #{log_file} for details")
        exception.log_file = log_file
      else
        exception = UnknownLatexBuildException.new("pdflatex failed for unknown reasons")
      end
      raise exception
    end
  end

  def run_latex_command(configuration)
    Process.waitpid(
      fork do
        begin
          Dir.chdir dir
          STDOUT.reopen(log_file,"a")
          STDERR.reopen(STDOUT)
          args = configuration[:arguments] + %w[-shell-escape -interaction batchmode input.tex]
          system(configuration[:command], '-draftmode', *args) if configuration[:parse_twice]
          exec(configuration[:command], *args)
        rescue
          File.open(log_file,'a') {|io|
            io.write("#{$!.message}:\n#{$!.backtrace.join("\n")}\n")
          }
        ensure
          Process.exit! 1
        end
      end
    )
  end

  def pdf_file
    input.sub(/\.tex$/,'.pdf')
  end

  def log_file
    input.sub(/\.tex$/,'.log')
  end

  def write_tex_to_file(tex)
    File.open(input,'wb') {|io| io.write(tex) }
  end

  def create_directory(directory)
    FileUtils.mkdir_p(directory)
  end

  def input
    @input ||= File.join(dir,'input.tex')
  end

  def dir
    @dir ||= File.join(Rails.root,'tmp','rails-latex',"#{Process.pid}-#{Thread.current.hash}#{Time.now.to_f}")
  end
end
