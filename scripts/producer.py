#!/usr/bin/env python3

from selenium import webdriver
from selenium.webdriver.chrome.service import Service as ChromeService
# from webdriver_manager.chrome import ChromeDriverManager

options = webdriver.ChromeOptions()
#options.binary_location = '/usr/bin/google-chrome'
#options.add_argument('--headless')
#options.add_argument('--no-sandbox')
#options.add_argument('--disable-dev-shm-usage')
options.add_argument("--start-maximized")

with webdriver.Remote(command_executor='http://localhost:4444/wd/hub', options=options) as driver:
	driver.get("https://localhost:3000/?roomId=devel&info=true&_throttleSecret=foo&consume=false&externalVideo=true&forceVP9=true")

#driver = webdriver.Chrome(service=ChromeService(ChromeDriverManager().install()), options=options)
#driver.get("https://www.google.com")

