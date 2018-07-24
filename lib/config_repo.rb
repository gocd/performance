##########################################################################
# Copyright 2018 ThoughtWorks, Inc.
#
# Licensed under the Apache License, Version 2.0 (the License);
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an AS IS BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##########################################################################

require './lib/configuration'
require './lib/material'

include Configuration

module Material
  class ConfigRepo
    def initialize
      @setup = SetUp.new
    end

    def update_repo
      cd "#{@setup.git_root}/config-repo-git" do
        time = Time.now
        File.write('file', time.to_f)
        sh("git add .;git commit -m 'This is commit at #{time.rfc2822}' --author 'foo <foo@bar.com>'; git gc;")
      end 
    end

    def create_repo(pipeline, file_name)
      cd "#{@setup.git_root}/config-repo-git" do
        time = Time.now
        File.open(file_name, 'w') { |file| file.write(pipeline) }
        sh("git add .;git commit -m 'This is Config repo commit at #{time.rfc2822}' --author 'foo <foo@bar.com>'; git gc;")
      end 
    end

  end

end
