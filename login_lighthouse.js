const fs = require('fs');
const puppeteer = require('puppeteer');
const lighthouse = require('lighthouse');
const ReportGenerator = require('lighthouse/lighthouse-core/report/report-generator');

// This port will be used by Lighthouse later. The specific port is arbitrary.
const PORT = 8041;

/**
 * @param {import('puppeteer').Browser} browser
 * @param {string} origin
 */
async function login(browser, origin) {
  const page = await browser.newPage();
  await page.goto(origin);
  await page.waitForSelector('input[type="password"]', {visible: true});

  // Fill in and submit login form.
  const passwordInput = await page.$('input[type="password"]');
  await passwordInput.type(process.env.NETLIFY_AUTH);
  await Promise.all([
    page.$eval('form', form => form.submit()),
    page.waitForNavigation(),
  ]);

  await page.close();
}

async function main() {
  // Direct Puppeteer to open Chrome with a specific debugging port.
  const browser = await puppeteer.launch({
    executablePath: '/usr/bin/google-chrome-stable',
    args: [`--remote-debugging-port=${PORT}`, '--disable-gpu', '--no-sandbox', '--no-zygote'],
    // Optional, if you want to see the tests in action.
    headless: true,
  });

  // Setup the browser session to be logged into our site.
  await login(browser, process.env.URL);

  // The local server is running on port 10632.
  const url = process.env.URL;

  // Direct Lighthouse to use the same port.
  const results = await lighthouse(url, {onlyCategories: ['performance'], port: PORT, disableStorageReset: true})
  const html = ReportGenerator.generateReport(results.lhr, 'html');
  fs.writeFileSync(`${process.env.REPORT_PATH}.report.html`, html);
  fs.writeFileSync(`${process.env.REPORT_PATH}.report.json`, results.report);

  // Direct Puppeteer to close the browser as we're done with it.
  await browser.close();
}

if (require.main === module) {
  main();
} else {
  module.exports = {
    login,
  };
}
