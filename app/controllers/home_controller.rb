class HomeController < ApplicationController
  def index

  end

  def alive
    render json: {}
  end

  def pandora
    status = pandora = []
    crushes = ['carolinamonteiroana', 'natz.souza', 'mirella.martins.1422']
    fb_scrape = FacebookScraper.new
    crushes.each do |crush|
      relationship = fb_scrape.scrape(crush)
      status << { crush => relationship }
      pandora << crush if relationship == "Solteira"
    end
    render json: { 
      open: pandora.present?, 
      pandora: pandora,
      status: status 
    }
  end
end
