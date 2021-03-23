module AfipBill
  class User
    attr_accessor :company_name, :owner_name, :address, :tax_category, :document_type, :afip_document_type, :student_name

    def initialize(company_name, owner_name, address, tax_category, document_type, afip_document_type, student_name)
      @company_name = company_name
      @owner_name = owner_name
      @address = address
      @tax_category = tax_category
      @document_type = document_type
      @afip_document_type = afip_document_type
      @student_name = student_name
    end
  end
end
