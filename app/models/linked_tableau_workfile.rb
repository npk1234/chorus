class LinkedTableauWorkfile < ChorusWorkfile

  has_one :tableau_workbook_publication
  delegate :workbook_url, :to => :tableau_workbook_publication, :allow_nil => true
  delegate :name, :to => :tableau_workbook_publication, :prefix => :workbook, :allow_nil => true

  def content_type
    "tableau_workbook"
  end
end