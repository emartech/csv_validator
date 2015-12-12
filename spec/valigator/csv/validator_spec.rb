require 'spec_helper'

module Valigator
  module CSV
    describe Validator do
      describe '#validate' do
        it 'should collect no errors for valid files' do
          subject = described_class.new fixture('valid.csv')
          subject.validate

          expect(subject.errors).to eq []
        end


        it 'should use the provided dialect to parse the CSV' do
          subject = described_class.new fixture('valid_custom.csv')
          subject.validate col_sep: ";", quote_char: "'"

          expect(subject.errors).to eq([])
        end


        it "forwards csv header options" do
          subject = described_class.new fixture('valid.csv')
          expect(::CSV).to receive(:foreach).with(fixture('valid.csv'), col_sep: ',', quote_char: '"', encoding: 'UTF-8', headers: true, return_headers: false)

          subject.validate headers: true, return_headers: false
        end


        it 'should detect invalid byte sequence when opening with default encoding' do
          subject = described_class.new fixture('invalid_encoding.csv')
          subject.validate

          expect(subject.errors).to eq([Error.new(row: nil, type: 'invalid_encoding', message: 'invalid byte sequence in UTF-8')])
        end


        it 'should not report byte sequence error when opened with the correct encoding' do
          subject = described_class.new fixture('invalid_encoding.csv')
          subject.validate(encoding: 'ISO-8859-9')

          expect(subject.errors).to eq([])
        end


        it 'should detect quoting problems' do
          subject = described_class.new fixture('unclosed_quote.csv')
          subject.validate

          expect(subject.errors).to eq [Error.new(row: 4, type: 'unclosed_quote', message: 'Unclosed quoted field on line 4.')]
        end


        it 'should (re)raise error, if it is not directly parsing related' do
          subject = described_class.new fixture('unclosed_quote.csv')

          expect { subject.validate quote_char: 'asd'}.to raise_error ArgumentError, ':quote_char has to be a single character String'
        end


        context 'mandatory field' do
          subject { described_class.new fixture('missing_mandatory_field.csv') }

          it 'does not validate unless fields given' do
            options = {
              field_validators: {
                "id" => Valigator::CSV::FieldValidators::Mandatory.new
              }
            }

            subject.validate(options)
            expect(subject.errors).to eq []
          end

          it 'does not validate unless field validators given' do
            options = {
              fields: %w(id name)
            }

            subject.validate(options)
            expect(subject.errors).to eq []
          end

          it 'reports field with nil value' do
            options = {
              fields: %w(id name),
              field_validators: {
                "id" => Valigator::CSV::FieldValidators::Mandatory.new
              }
            }

            subject.validate(options)

            expect(subject.errors).to eq [
              Error.new(type: 'missing_field', message: 'Missing mandatory field', row: 4, field: 'id')
            ]
          end
        end


        context 'abort validation' do
          subject { described_class.new fixture('too_many_errors.csv') }
          let(:config) { Hash[
              headers: true,
              fields: %w(order date customer item c_sales_amount quantity unit_price),
              field_validators: {
                  "order" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d'),
                  "date" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d'),
                  "customer" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d'),
                  "ite±m" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d'),
                  "c_sales_amount" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d'),
                  "quantity" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d'),
                  "unit_price" => Valigator::CSV::FieldValidators::Date.new(format: '%Y%m%d')
              }
          ] }


          it 'aborts when reaching default value' do
            subject.validate(config)

            expect(subject.errors.size).to eq(1000 + 1)
            expect(subject.errors.last).to eq(Error.new(type: 'too_many_errors',  message: 'Too many errors were found'))
          end


          it 'aborts when reaching value given as option' do
            subject.validate(config.merge(errors_limit: 1))

            expect(subject.errors.size).to eq(1 + 1)
            expect(subject.errors.last).to eq(Error.new(type: 'too_many_errors',  message: 'Too many errors were found'))
          end


          it 'setting the limit to nil disables the limit' do
            subject.validate(config.merge(errors_limit: nil))

            expect(subject.errors.size).to be > 1000
            expect(subject.errors.last).not_to eq(Error.new(type: 'too_many_errors',  message: 'Too many errors were found'))
          end
        end

      end
    end

  end
end