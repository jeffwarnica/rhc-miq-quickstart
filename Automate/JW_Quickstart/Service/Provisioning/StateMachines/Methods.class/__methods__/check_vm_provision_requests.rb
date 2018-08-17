#
# CloudForms Method Name: check_vm_provision_requests.rb
#
# Description: Check all VM provision requests from the vm_prov_request_ids
#       state variable and ensure that they are complete before moving on.
#
# jcutter@redhat.com 2017-10-23
# jwarnica@redhat.com 2018-08-16 - Move to class format and longer loging


module JW_Quickstart
  module Automate
    module Service
      module Provisioning
        module StateMachines
          class CheckVmProvisionRequests
            include RedHatConsulting_Utilities::StdLib::Core

            def initialize(handle = $evm)
              @handle = handle
              @DEBUG = false
            end

            # def log(level, msg, update_message = false)
            #   @handle.log(level, "#{msg}")
            #   @task.message = msg if @task && (update_message || level == 'error')
            # end

            def main

              @task = @handle.root['service_template_provision_task']
              @service = @task.destination

              vm_prov_request_ids = @handle.get_state_var(:vm_prov_request_ids)

              raise 'State var :vm_prov_request_ids is blank!' if vm_prov_request_ids.blank?

              log(:info, "Investigating miq_requests [#{vm_prov_request_ids.join(',')}]")

              waiting_on = []
              vm_prov_request_ids.each do |vm_request_id|
                vm_request = @handle.vmdb(:miq_request, vm_request_id)
                unless vm_request.status == 'Ok'
                  raise "miq_request #{vm_request_id} has an unexpected status of: #{vm_request.status}, aborting."
                end
                log(:info, "child [#{vm_request_id}] vm_request.state: #{vm_request.state}")
                unless vm_request.state == 'finished'
                  waiting_on << vm_request_id
                end
              end
              
              log(:info, "XXXXXXXX waiting_on now: [#{waiting_on.join(',')}]")

              unless waiting_on.empty?
                interval = '60.seconds'
                log(:info, "Waiting for miq_requests [#{waiting_on.join(',')}] to finish. Will recheck in #{interval}.", true)
                @handle.root['ae_result'] = 'retry'
                @handle.root['ae_retry_interval'] = interval
                exit MIQ_OK
              end

            rescue => err
              log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
              @task['status'] = 'Error' if @task
              @task.finished("#{err}") if @task
              @service.remove_from_vmdb if @service
              exit MIQ_ABORT
            end

          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  JW_Quickstart::Automate::Service::Provisioning::StateMachines::CheckVmProvisionRequests.new.main
end
