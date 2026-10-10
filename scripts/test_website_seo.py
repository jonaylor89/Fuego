#!/usr/bin/env python3
"""Offline SEO regression checks. Run: python3 scripts/test_website_seo.py"""

import json
from html.parser import HTMLParser
from pathlib import Path
import unittest
from urllib.parse import urlsplit
from urllib.robotparser import RobotFileParser
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1] / "website"
ORIGIN = "https://getfuego.dev"
CANONICAL = ORIGIN + "/"


class PageParser(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.tags = []
        self.title = ""
        self.json_ld = ""
        self.active = None
        self.feed(source)
        self.close()

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        self.tags.append((tag, attrs))
        if tag == "title":
            self.active = "title"
        elif tag == "script" and attrs.get("type") == "application/ld+json":
            self.active = "json_ld"

    def handle_endtag(self, tag):
        if tag in ("title", "script"):
            self.active = None

    def handle_data(self, data):
        if self.active:
            setattr(self, self.active, getattr(self, self.active) + data)


class WebsiteSEOTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.page = PageParser((ROOT / "index.html").read_text(encoding="utf-8"))
        cls.graph = json.loads(cls.page.json_ld)

    def meta(self, key):
        values = [attrs["content"] for tag, attrs in self.page.tags
                  if tag == "meta" and key in (attrs.get("name"), attrs.get("property"))]
        self.assertEqual(len(values), 1, f"Expected exactly one {key} meta tag")
        return values[0]

    def test_search_metadata(self):
        self.assertTrue(self.page.title.startswith("Fuego"))
        self.assertIn("Blocker for Mac", self.page.title)
        self.assertLessEqual(len(self.page.title), 60)
        description = self.meta("description")
        self.assertIn("free, open-source", description)
        self.assertIn("macOS 15.5+", description)
        self.assertLessEqual(len(description), 160)
        canonicals = [attrs["href"] for tag, attrs in self.page.tags
                      if tag == "link" and attrs.get("rel") == "canonical"]
        self.assertEqual(canonicals, [CANONICAL])
        self.assertIn(("html", {"lang": "en"}), self.page.tags)
        self.assertEqual(sum(tag == "h1" for tag, _ in self.page.tags), 1)
        self.assertNotIn("noindex", self.meta("robots"))
        self.assertIn("max-image-preview:large", self.meta("robots"))

    def test_social_previews(self):
        self.assertEqual(self.meta("og:url"), CANONICAL)
        self.assertEqual(self.meta("og:type"), "website")
        self.assertEqual(self.meta("og:site_name"), "Fuego")
        self.assertEqual(self.meta("twitter:card"), "summary_large_image")
        for prefix in ("og", "twitter"):
            self.assertEqual(self.meta(prefix + ":title"), self.page.title)
            self.assertEqual(self.meta(prefix + ":description"), self.meta("description"))
            self.assertTrue(self.meta(prefix + ":image:alt"))
        self.assertEqual(self.meta("twitter:image"), self.meta("og:image"))
        screenshot = next(attrs for tag, attrs in self.page.tags
                          if tag == "img" and attrs.get("class") == "demo")
        self.assertEqual(self.meta("og:image"), ORIGIN + "/" + screenshot["src"])
        self.assertEqual(self.meta("og:image:width"), screenshot["width"])
        self.assertEqual(self.meta("og:image:height"), screenshot["height"])
        self.assertEqual(self.meta("og:image:type"), "image/jpeg")

    def test_structured_data(self):
        self.assertEqual(self.graph["@context"], "https://schema.org")
        entities = {node["@type"]: node for node in self.graph["@graph"]}
        site, page, app = (entities[k] for k in ("WebSite", "WebPage", "SoftwareApplication"))
        for entity in (site, page, app):
            self.assertEqual(entity["url"], CANONICAL)
        self.assertEqual(page["isPartOf"]["@id"], site["@id"])
        self.assertEqual(page["mainEntity"]["@id"], app["@id"])
        self.assertEqual(page["name"], self.page.title)
        self.assertEqual(page["description"], self.meta("description"))
        self.assertEqual(app["applicationCategory"], "ProductivityApplication")
        self.assertEqual(app["operatingSystem"], "macOS 15.5 or later")
        self.assertEqual(app["offers"]["price"], "0")
        self.assertEqual(app["offers"]["priceCurrency"], "USD")
        download = next(attrs["href"] for tag, attrs in self.page.tags
                        if tag == "a" and attrs.get("class") == "button")
        self.assertEqual(app["downloadUrl"], download)
        self.assertEqual(app["offers"]["url"], download)
        self.assertEqual(app["screenshot"], self.meta("og:image"))
        # Never invent reviews or ratings to qualify for search rich results.
        self.assertNotIn("aggregateRating", app)
        self.assertNotIn("review", app)

    def test_direct_download(self):
        download = next(attrs["href"] for tag, attrs in self.page.tags
                        if tag == "a" and attrs.get("class") == "button")
        self.assertEqual(download, "https://github.com/jonaylor89/Fuego/releases/latest/download/Fuego.dmg")

    def test_local_assets_exist(self):
        urls = []
        for tag, attrs in self.page.tags:
            if tag in ("img", "script") and "src" in attrs:
                urls.append(attrs["src"])
            if tag == "link" and attrs.get("rel") in ("icon", "apple-touch-icon", "manifest", "stylesheet"):
                href = attrs["href"]
                if attrs["rel"] != "stylesheet" or not urlsplit(href).netloc:
                    urls.append(href)
        app = next(n for n in self.graph["@graph"] if n["@type"] == "SoftwareApplication")
        urls.extend((self.meta("og:image"), self.meta("twitter:image"), app["image"], app["screenshot"]))
        for url in urls:
            parsed = urlsplit(url)
            self.assertIn(parsed.netloc, ("", "getfuego.dev"))
            if parsed.netloc:
                self.assertEqual(parsed.scheme, "https")
            self.assertTrue((ROOT / parsed.path.lstrip("/")).is_file(), f"Missing asset: {url}")

    def test_crawl_configuration(self):
        sitemap = ET.parse(ROOT / "sitemap.xml")
        locations = [node.text for node in sitemap.findall("{*}url/{*}loc")]
        self.assertEqual(locations, [CANONICAL])
        robots = RobotFileParser()
        robots.parse((ROOT / "robots.txt").read_text(encoding="utf-8").splitlines())
        self.assertEqual(robots.site_maps(), [ORIGIN + "/sitemap.xml"])
        for agent in ("Googlebot", "Bingbot", "Twitterbot", "facebookexternalhit"):
            for url in (CANONICAL, self.meta("og:image")):
                self.assertTrue(robots.can_fetch(agent, url), f"Blocked: {agent} {url}")


if __name__ == "__main__":
    unittest.main()
