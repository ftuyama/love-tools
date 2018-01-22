require 'capybara/dsl'

Capybara.configure do |config|
  config.run_server = false
  # config.default_driver = :poltergeist
  config.default_driver = :chrome
  config.app_host = 'https://www.facebook.com'
  config.ignore_hidden_elements = false
end

Capybara.register_driver :chrome do |app|
  prefs = {
    download: {
      prompt_for_download: false,
      default_directory: "#{Dir.pwd}/tmp/downloads"
    }
  }
  Capybara::Selenium::Driver.new(app, browser: :chrome, prefs: prefs)
end

Dotenv.load

class FacebookScraper
  include Capybara::DSL

  def initialize
    login
  end

  def scrape(username)
    scrape_relationship(username)
    #scrape_photos(username)
  end

  private

  def find_link_elems_with(href)
    all('a').select { |elem| elem[:href] && elem[:href].include?(href) }
  end

  def find_links_with(href)
    find_link_elems_with(href).map { |elem| elem[:href] }.uniq
  end

  def download_photo
    find('.fbPhotoSnowliftDropdownButton').click

    begin
      find('a[data-action-type="download_photo"]', visible: true).click
    rescue Capybara::ElementNotFound
      # TODO(maros): Is there a download method in Capybara `chromedriver`?
      execute_script("
        link = document.createElement('a');
        link.href = document.querySelector('.spotlight').src;
        link.setAttribute('download', 'download');
        link.click();")
    end
  end

  def scrape_album(href)
    visit(href)

    # HACK(maros): Make the backdrop for Chrome Notifications go away. Find a
    # pref for `chromedriver` to make this disabled by default.
    find('._3ixn').click

    photo_links = []

    # Get all photos to load despite infinite scroll.
    loop do
      execute_script('window.scrollTo(0, document.body.scrollHeight);')
      links = find_link_elems_with('/photo.php')
      break if links.length - photo_links.length == 0
      photo_links = links
    end

    # Remove the cover photo and profile photo.
    photo_links.shift
    photo_links.shift

    if photo_links.length == 0
      return
    end

    photo_links.first.click
    photo_links.length.times do
      download_photo

      begin
        find('.snowliftPager.next').click

      # If the photo album has only one image, this element won't exist.
      rescue Selenium::WebDriver::Error::ElementNotVisibleError
        break
      end
    end

    # Add directory name for album.
    title = find('.fbPhotoAlbumTitle').text.downcase.gsub(' ', '_')

    begin
      File.rename("#{Dir.pwd}/tmp/downloads", "#{Dir.pwd}/tmp/#{title}")

    # This will fail if no files were downloaded because the `tmp/downloads`
    # directory will not exist.
    rescue Errno::ENOENT
    end
  end

  def scrape_relationship(username)
    visit("/#{username}")
    intro = find('#intro_container_id')
    begin
      heart = intro.find('.sx_a00452')
      heart.sibling('._42ef').text
    rescue
      "-"
    end
  end

  def scrape_photos(username)
    visit("/#{username}/photos_albums")
    find_links_with('/media/set').each { |link| scrape_album(link) }
  end

  def login
    visit('/login')
    return if page.has_content?('Felipe')
    fill_in('email', with: ENV['FACEBOOK_EMAIL'])
    fill_in('pass',  with: ENV['FACEBOOK_PASSWORD'])
    click_button('loginbutton')

    while has_css?('#approvals_code')
      print 'Enter your 6-digit login code: '
      fill_in('approvals_code', with: gets.chomp)
      click_button('checkpointSubmitButton')
    end

    while has_css?('#checkpointSubmitButton')
      click_button('checkpointSubmitButton')
    end
  end
end
