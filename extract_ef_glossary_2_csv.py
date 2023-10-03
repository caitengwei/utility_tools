#!/usr/bin/env python

"""
将EF词汇表 pdf 转为 csv，方便录入ios/mac的背生词app，比如wokabulary.
CSV 按照 Word | Translation | Spell | Tags 组织.
"""

import pdfplumber
import csv
import sys
import os

def extract_and_save_table(pdf_path):
    # 获取不带 .pdf 后缀的文件名
    dir_path = os.path.dirname(pdf_path)
    filename = os.path.splitext(os.path.basename(pdf_path))[0]
    csv_path = filename + '.csv'

    with pdfplumber.open(pdf_path) as pdf:
        with open(os.path.join(dir_path, csv_path), 'w', newline='') as csv_file:
            csv_writer = csv.writer(csv_file, delimiter=';', quotechar='"', quoting=csv.QUOTE_ALL)

            # 遍历 PDF 的每一页
            for page in pdf.pages:
                tables = page.extract_tables()

                # 遍历页面中的每张表格
                for table in tables:
                    for row in table[1:]:
                        if len(row) != 4:
                            print(f"Skipping row with {len(row)} columns (expected 4 columns)")
                            continue
                        # 按照指定的顺序重排列列，并将文件名添加为第四列
                        new_row = [row[0], row[3], row[1], filename]
                        csv_writer.writerow(new_row)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <path_to_pdf>")
        sys.exit(1)

    pdf_path = sys.argv[1]
    if not os.path.exists(pdf_path):
        print(f"File {pdf_path} does not exist.")
        sys.exit(1)

    extract_and_save_table(pdf_path)
