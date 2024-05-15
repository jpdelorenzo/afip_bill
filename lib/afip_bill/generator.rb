require "json"
require "date"
require "afip_bill/check_digit"
require "pdfkit"
require "rqrcode"
require "humanize"

module AfipBill
  class Generator
    attr_reader :afip_bill, :bill_type, :user, :line_items, :header_text, :total_in_text, :total_cents_in_text

    AFIP_QR_URL = 'https://www.afip.gob.ar/fe/qr/'
    HEADER_PATH = File.dirname(__FILE__) + '/views/shared/_factura_header.html.erb'.freeze
    FOOTER_PATH = File.dirname(__FILE__) + '/views/shared/_factura_footer.html.erb'.freeze
    BRAVO_CBTE_TIPO = { "01" => "Factura A", "06" => "Factura B", "11" => "Factura C" }.freeze
    IVA = 21.freeze

    def initialize(bill, user, line_items = [], header_text = 'ORIGINAL')
      @afip_bill = JSON.parse(bill)
      @user = user
      @bill_type = type_a_or_b_bill
      @line_items = line_items
      @template_header = ERB.new(File.read(HEADER_PATH)).result(binding)
      @template_footer = ERB.new(File.read(FOOTER_PATH)).result(binding)
      @header_text = header_text
      @total_in_text = afip_bill["imp_total"].to_i.humanize(locale: :es)
      @total_cents_in_text = (afip_bill["imp_total"].modulo(1) * 100).round.humanize(locale: :es)
    end

    def type_a_or_b_bill
      BRAVO_CBTE_TIPO[afip_bill["cbte_tipo"]][-1].downcase
    end

    def qr_code_data_url
      @qr_code ||= RQRCode::QRCode.new(qr_code_string).as_png(
        bit_depth: 1,
        border_modules: 2,
        color_mode: ChunkyPNG::COLOR_GRAYSCALE,
        color: 'black',
        file: nil,
        fill: 'white',
        module_px_size: 12,
        resize_exactly_to: false,
        resize_gte_to: false,
        size: 120
      ).to_data_url
    end

    def generate_pdf_file
      tempfile = Tempfile.new(["factura_afip", '.pdf' ])
      PDFKit.new(template, disable_smart_shrinking: true).to_file(tempfile.path)
    end

    def generate_pdf_string
      PDFKit.new(template, disable_smart_shrinking: true).to_pdf
    end

    def bill_path
      File.dirname(__FILE__) + "/views/bills/factura_#{bill_type}.html.erb" 
    end

    def qr_code_string
      "#{AFIP_QR_URL}?p=#{Base64.urlsafe_encode64(qr_hash.to_json)}"
    end

    def qr_hash
      {
        ver: 1,
        fecha: Date.parse(afip_bill["cbte_fch"]).strftime("%Y-%m-%d"),
        cuit: AfipBill.configuration[:business_cuit].to_i,
        ptoVta: AfipBill.configuration[:sale_point].to_i,
        tipoCmp: afip_bill["cbte_tipo"].to_i,
        nroCmp: afip_bill["cbte_hasta"].to_s.rjust(8, "0").to_i,
        importe: afip_bill["imp_total"],
        moneda: "PES",
        ctz: 1,
        tipoDocRec: afip_bill["doc_tipo"].to_i,
        nroDocRec: afip_bill["doc_num"].tr("-", "").strip.to_i,
        tipoCodAut: "E",
        codAut: afip_bill["cae"].to_i
      }
    end

    def template
      ERB.new(File.read(bill_path)).result(binding)
    end
  end
end
