describe("chorus.dialogs.ExistingTableImportCSV", function() {
    beforeEach(function() {
        chorus.page = {};
        this.sandbox = fixtures.sandbox({
            schemaName: "mySchema",
            databaseName: "myDatabase",
            instanceName: "myInstance"
        })
        chorus.page.workspace = fixtures.workspace();
        this.csv = fixtures.csvImport({lines: [
            "COL1,col2, col3 ,col 4,Col_5",
            "val1.1,val1.2,val1.3,val1.4,val1.5",
            "val2.1,val2.2,val2.3,val2.4,val2.5",
            "val3.1,val3.2,val3.3,val3.4,val3.5"
        ],
            toTable: "existingTable"
        });
        this.dialog = new chorus.dialogs.ExistingTableImportCSV({csv: this.csv});
        this.dialog.render();
    });

    it("has the title", function() {
        expect(this.dialog.$('h1')).toContainTranslation("dataset.import.table.title");
    });

    it("has an import button", function() {
        expect(this.dialog.$('button.submit')).toContainTranslation("dataset.import.table.submit");
    });

    it("has comma as the default separator", function() {
        expect(this.dialog.$('input[name=delimiter]:checked').val()).toBe(',');
    });

    describe("click the 'tab' separator", hasRightSeparator('\t'));
    describe("click the 'comma' separator", hasRightSeparator(','));
    describe("click the 'semicolon' separator", hasRightSeparator(';'));
    describe("click the 'space' separator", hasRightSeparator(' '));

    function hasRightSeparator(separator) {
        return function() {
            beforeEach(function() {
                this.csv = fixtures.csvImport({lines: [
                    "COL1" + separator + "col2" + separator + "col3" + separator + "col_4" + separator + "Col_5",
                    "val1.1" + separator + "val1.2" + separator + "val1.3" + separator + "val1.4" + separator + "val1.5",
                    "val2.1" + separator + "val2.2" + separator + "val2.3" + separator + "val2.4" + separator + "val2.5",
                    "val3.1" + separator + "val3.2" + separator + "val3.3" + separator + "val3.4" + separator + "val3.5"
                ],
                    toTable: "existingTable"
                });
                this.dialog = new chorus.dialogs.ExistingTableImportCSV({csv: this.csv});
                this.dialog.render();

                this.dialog.$("input.delimiter[value='" + separator + "']").click();
            });

            it("has " + separator + " as separator", function() {
                expect(this.dialog.$('input.delimiter[checked]').val()).toBe(separator);
            });

            it("reparses the file with " + separator + " as the separator", function() {
                expect(this.dialog.$(".data_table .tbody .column").length).toEqual(5);
            });
        };
    }

    describe("other delimiter input field", function() {
        beforeEach(function() {
            this.otherField = this.dialog.$('input[name=custom_delimiter]');
        });

        it("is empty on loading", function() {
            expect(this.otherField.val()).toBe("");
        });

        it("checks the Other radio button", function() {
            this.otherField.val("X");
            this.otherField.trigger("keyup");
            expect(this.dialog.$('input.delimiter[type=radio]:checked').val()).toBe("other");
        });

        it("retains its value after re-render", function() {
            this.otherField.val("X");
            this.otherField.trigger("keyup");
            expect(this.otherField).toHaveValue("X");
        });

        describe("clicking on radio button Other", function() {
            beforeEach(function() {
                spyOn($.fn, 'focus');
                this.dialog.$("input#delimiter_other").click();
            });

            it("focuses the text field", function() {
                expect($.fn.focus).toHaveBeenCalled();
                expect($.fn.focus.mostRecentCall.object).toBe("input:text");
            });

            describe("entering 'z' as a separator", function() {
                beforeEach(function() {
                    this.csv = fixtures.csvImport({lines: [
                        "COL1zcol2zcol3zcol_4zCol_5",
                        "val1.1zval1.2zval1.3zval1.4zval1.5",
                        "val2.1zval2.2zval2.3zval2.4zval2.5",
                        "val3.1zval3.2zval3.3zval3.4zval3.5"
                    ],
                        toTable: "existingTable"
                    });
                    this.dialog = new chorus.dialogs.ExistingTableImportCSV({csv: this.csv});
                    this.dialog.render();

                    this.dialog.$("input#delimiter_other").click();
                    this.dialog.$('input[name=custom_delimiter]').val("z");
                    this.dialog.$('input[name=custom_delimiter]').trigger('keyup')
                });

                it("has z as separator", function() {
                    expect(this.dialog.$('input.delimiter[checked]').val()).toBe('other');
                });

                it("reparses the file with z as the separator", function() {
                    expect(this.dialog.$(".data_table .tbody .column").length).toEqual(5);
                });
            });
        })
    });

    it("has directions", function() {
        expect(this.dialog.$('.directions')).toContainTranslation("dataset.import.table.existing.directions",
            {
                toTable: "existingTable"
            });
    });

    it("checked the include header row checkbox by default", function() {
        expect(this.dialog.$("#include_header")).toBeChecked();
    });

    describe("the data table", function() {
        it("has the right number of column names", function() {
            expect(this.dialog.$(".data_table .thead .column_names .th").length).toEqual(5);
        })

        it("converts the column names into db friendly format", function() {
            var $columnNames = this.dialog.$(".data_table .thead .column_names .th");
            expect($columnNames.eq(0).text()).toBe("col1")
            expect($columnNames.eq(1).text()).toBe("col2")
            expect($columnNames.eq(2).text()).toBe("col3")
            expect($columnNames.eq(3).text()).toBe("col_4")
            expect($columnNames.eq(4).text()).toBe("col_5")
        })

        it("has the right number of column column mapping headers", function() {
            expect(this.dialog.$(".data_table .thead .column_mapping .th").length).toEqual(5);
        })


        it("has the right number of data columns", function() {
            expect(this.dialog.$(".data_table .tbody .column").length).toEqual(5);
        })

        it("displays the provided types", function() {
            _.each(this.dialog.$(".th .type"), function(th, index) {
                expect($(th).find(".chosen").text().trim()).toBe(this.csv.columnOrientedData()[index].type);
            }, this);
        });

        it("has the right data in each cell", function() {
            _.each(this.dialog.$(".data_table .tbody .column"), function(column, i) {
                var cells = $(column).find(".td")
                expect(cells.length).toEqual(3);
                _.each(cells, function(cell, j) {
                    expect($(cell)).toContainText("val" + (j + 1) + "." + (i + 1));
                })
            });
        });

        describe("selecting a destination column", function() {
            beforeEach(function() {
                this.qtip = stubQtip();
                this.dialog.$(".column_mapping .map:eq(1)").click();
            })

            xit("shows a qtip", function() {
                expect(this.qtip).toHaveVisibleQtip()
            })
        })
    });

    describe("unchecking the include header box", function() {
        beforeEach(function() {
            spyOn(this.dialog, "postRender").andCallThrough();
            spyOn(this.dialog, "recalculateScrolling").andCallThrough();
            this.dialog.$("#include_header").removeAttr("checked");
            this.dialog.$("#include_header").change();
        })

        it("sets header on the csv model", function() {
            expect(this.dialog.csv.get("include_header")).toBeFalsy();
        });

        it("re-renders", function() {
            expect(this.dialog.postRender).toHaveBeenCalled();
        });

        it("the box is unchecked", function() {
            expect(this.dialog.$("#include_header").attr("checked")).toBeFalsy();
        });

        it("calls recalculate Scrolling", function() {
            expect(this.dialog.recalculateScrolling).toHaveBeenCalled();
        });

        describe("rechecking the box", function() {
            beforeEach(function() {
                this.dialog.postRender.reset();
                this.dialog.$("#include_header").attr("checked", "checked");
                this.dialog.$("#include_header").change();
            })
            it("sets header on the csv model", function() {
                expect(this.dialog.csv.get("include_header")).toBeTruthy();
            })
            it("re-renders", function() {
                expect(this.dialog.postRender).toHaveBeenCalled();
            })
            it("the box is checked", function() {
                expect(this.dialog.$("#include_header").attr("checked")).toBeTruthy();
            })
        })
    });

    describe("scrolling the data", function() {
        beforeEach(function() {
            spyOn(this.dialog, "adjustHeaderPosition").andCallThrough();
            this.dialog.render();
            this.dialog.$(".tbody").trigger("scroll");
        });
        it("sets the header position", function() {
            expect(this.dialog.adjustHeaderPosition).toHaveBeenCalled();
        });
    })

    describe("clicking the import button", function() {
        beforeEach(function() {
            spyOn(this.dialog, "closeModal");
            this.dialog.$("button.submit").click();
        });

        it("starts the spinner", function() {
            expect(this.dialog.$("button.submit").isLoading()).toBeTruthy();
            expect(this.dialog.$("button.submit").text().trim()).toMatchTranslation("dataset.import.importing");
        });

        it("imports the file", function() {
            expect(this.server.lastCreate().url).toBe(this.dialog.csv.url());
            var params = this.server.lastCreate().params();
            expect(params.fileName).toBe(this.dialog.csv.get("fileName"));
            expect(params.toTable).toBe("existingTable");
            expect(params.delimiter).toBe(",");
        });

        context("when the post to import responds with success", function() {
            beforeEach(function() {
                spyOn(chorus, 'toast');
                spyOn(chorus.PageEvents, 'broadcast');
                this.server.lastCreateFor(this.dialog.csv).succeed();
            });

            it("closes the dialog and displays a toast", function() {
                expect(this.dialog.closeModal).toHaveBeenCalled();
                expect(chorus.toast).toHaveBeenCalledWith("dataset.import.started");
            });

            it("triggers csv_import:started", function() {
                expect(chorus.PageEvents.broadcast).toHaveBeenCalledWith("csv_import:started");
            });
        })

        context("when the import fails", function() {
            beforeEach(function() {
                this.server.lastCreateFor(this.dialog.csv).fail([
                    {message: "oops"}
                ]);
            });

            it("displays the error", function() {
                expect(this.dialog.$(".errors")).toContainText("oops");
            });

            it("re-enables the submit button", function() {
                expect(this.dialog.$("button.submit").isLoading()).toBeFalsy();
            })
        })
    })
})
;
