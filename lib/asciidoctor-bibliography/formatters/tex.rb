module AsciidoctorBibliography
  module Formatters
    # This formatter emulates the behaviour of traditional Bib(La)TeX/NatBib citations.
    class TeX
      MACROS = {
        # NOTE: cite = citet
        'cite'        => { type: :textual,       bracketed: true,  authors: :abbreviated },
        'citet'       => { type: :textual,       bracketed: true,  authors: :abbreviated },
        'citet*'      => { type: :textual,       bracketed: true,  authors: :full },
        'citealt'     => { type: :textual,       bracketed: false, authors: :abbreviated },
        'citealt*'    => { type: :textual,       bracketed: false, authors: :full },
        'citep'       => { type: :parenthetical, bracketed: true,  authors: :abbreviated },
        'citep*'      => { type: :parenthetical, bracketed: true,  authors: :full },
        'citealp'     => { type: :parenthetical, bracketed: false, authors: :abbreviated },
        'citealp*'    => { type: :parenthetical, bracketed: false, authors: :full },
        'citeauthor'  => { type: :authors_only,  bracketed: false, authors: :abbreviated },
        'citeauthor*' => { type: :authors_only,  bracketed: false, authors: :full },
        'citeyear'    => { type: :years_only,    bracketed: false },
        'citeyearpar' => { type: :years_only,    bracketed: true }
      }

      attr_accessor :opening_bracket,
                    :closing_bracket,
                    :cites_separator,
                    :style,
                    :author_year_separator,
                    :years_separator

      def initialize(format)
        if format == 'numbers'
          bibpunct = '{[}{]}{,}{n}{,}{,}'
        elsif format == 'authoryear'
          bibpunct = '{(}{)}{;}{a}{,}{,}'
        else
          raise StandardError, "Unknown TeX citation format: #{format}"
        end
        @opening_bracket,
        @closing_bracket,
        @cites_separator,
        @style,
        @author_year_separator,
        @years_separator = bibpunct.scan(/{.*?}/).map { |s| s[1..-2] }
      end

      def import(database)
        @database = database
      end

      def render(citation)
        macro_options = MACROS[citation.macro]
        output = []
        case macro_options[:type]
        when :full
        # NOTE: deliberately repetitive to improve redability.
        when :textual
          citation.cites.each do |cite|
            authors = authors(macro_options[:authors], cite)
            if @style == 'n'
              year = cite.occurrence_index + 1
            else
              year = year(cite)
            end
            cetera = Helpers.join_nonempty([year].concat(extra(cite)), @years_separator + ' ')
            cetera = bracket(cetera) if macro_options[:bracketed]
            label = Helpers.join_nonempty([authors, cetera], ' ')
            output << citation.xref(cite.key, label)
          end
          output = output.join(@cites_separator + ' ')
        when :parenthetical
          citation.cites.each do |cite|
            if @style == 'n'
              authors = nil
              year = cite.occurrence_index + 1
            else
              authors = authors(macro_options[:authors], cite)
              year = year(cite)
            end
            cetera = Helpers.join_nonempty([year].concat(extra(cite)), @years_separator + ' ')
            label = Helpers.join_nonempty([authors, cetera], @author_year_separator + ' ')
            output << citation.xref(cite.key, label)
          end
          output = output.join(@cites_separator + ' ')
          output = bracket(output) if macro_options[:bracketed]
        when :authors_only
          citation.cites.each do |cite|
            authors = authors(macro_options[:authors], cite)
            year = nil
            cetera = Helpers.join_nonempty([year].concat(extra(cite)), @years_separator + ' ')
            label = Helpers.join_nonempty([authors, cetera], @author_year_separator + ' ')
            output << citation.xref(cite.key, label)
          end
          output = output.join(@cites_separator + ' ')
          output = bracket(output) if macro_options[:bracketed]
        when :years_only
          citation.cites.each do |cite|
            authors = nil
            year = year(cite)
            cetera = Helpers.join_nonempty([year].concat(extra(cite)), @years_separator + ' ')
            label = Helpers.join_nonempty([authors, cetera], @author_year_separator + ' ')
            output << citation.xref(cite.key, label)
          end
          output = output.join(@cites_separator + ' ')
          output = bracket(output) if macro_options[:bracketed]
        else
          raise StandardError, "Unknown TeX citation macro type: #{macro_options[:type]}"
        end

        output
      end

      private

      def bracket(string)
        [@opening_bracket, string, @closing_bracket].compact.join
      end

      def year(cite)
        issued = @database.find{ |h| h['id'] == cite.key }['issued']['date-parts']
        return "" if issued.nil?
        return "" if issued.first.nil?
        issued.first.first
      end

      def extra(cite)
        na = cite.named_attributes
        extra = []
        return extra if na.nil?
        # TODO: should this be configurable?
        extra << "Chapter #{na['chapter']}" unless na['chapter'].nil?
        extra << "Page #{na['page']}" unless na['page'].nil?
        extra
      end

      def authors(mode, cite)
        case mode
        when :full
          authors_full(cite)
        when :abbreviated
          authors_abbreviated(cite)
        else
          raise StandardError, "Unknown TeX citation authors mode: #{mode}"
        end
      end

      def authors_list(cite)
        authors = @database.find{ |h| h['id'] == cite.key }['author']
        return [] if authors.nil?
        authors.map{ |h| h['family'] }.compact
      end

      def authors_abbreviated(cite)
        authors = authors_list(cite)
        return "" if authors.empty?
        authors.length > 1 ? "#{authors.first} et al." : authors.first
      end

      def authors_full(cite)
        authors = authors_list(cite)
        return "" if authors.empty?
        Helpers.to_sentence authors
      end
    end
  end
end